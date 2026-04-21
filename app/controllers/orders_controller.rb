class OrdersController < ApplicationController
  FAILED_RETRY_LIMIT = 5
  FAILED_RETRY_WINDOW = 15.minutes

  before_action :authenticate_user!
  before_action :set_order, only: [ :show, :start_payment, :cancel_order, :payment_success, :payment_cancel ]
  rescue_from ActiveRecord::RecordNotFound, with: :handle_order_not_found

  def new
    nil unless prepare_checkout(default_checkout_profile)
  end

  def create
    submitted_profile = checkout_profile_params.to_h.symbolize_keys
    return unless prepare_checkout(submitted_profile)

    if params[:checkout_action] == "update_totals"
      flash.now[:notice] = "Totals updated for selected shipping details."
      render :new, status: :ok
      return
    end

    unless @profile_complete
      flash.now[:alert] = "Please provide a complete shipping address and province."
      render :new, status: :unprocessable_entity
      return
    end

    unavailable_item = stock_unavailable_item
    if unavailable_item.present?
      redirect_to cart_path, alert: "Not enough stock for #{unavailable_item[:product].display_common_name}."
      return
    end

    current_user.update!(
      address: @checkout_profile[:address],
      city: @checkout_profile[:city],
      postal_code: @checkout_profile[:postal_code],
      province_id: @checkout_profile[:province_id]
    )

    order = create_pending_order_from_checkout!

    session[:cart] = {}
    redirect_to order_path(order), notice: "Order created successfully."
  rescue ActiveRecord::RecordInvalid => e
    error_message = e.record.errors.full_messages.to_sentence.presence || "Unknown validation error."
    flash.now[:alert] = "Could not place order: #{error_message}."
    render :new, status: :unprocessable_entity
  end

  def index
    @orders = current_user.orders.order(created_at: :desc)
  end

  def show
  end

  def start_payment
    unless payment_start_allowed?
      redirect_to order_path(@order), alert: "Only pending or failed orders can start payment."
      return
    end

    if retry_throttled_for_failed_order?
      redirect_to order_path(@order), alert: "Too many payment retries. Please wait and try again."
      return
    end

    checkout_session = Stripe::Checkout::Session.create(
      mode: "payment",
      line_items: [
        {
          price_data: {
            currency: "cad",
            product_data: {
              name: "Rooted in Winnipeg Order ##{@order.id}"
            },
            unit_amount: @order.total_cents
          },
          quantity: 1
        }
      ],
      metadata: {
        order_id: @order.id.to_s,
        user_id: current_user.id.to_s
      },
      success_url: "#{payment_success_order_url(@order)}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: payment_cancel_order_url(@order)
    )

    @order.update!(
      stripe_payment_id: checkout_session.id
    )

    redirect_to checkout_session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    redirect_to order_path(@order), alert: "Unable to start Stripe payment: #{e.message}"
  end

  def cancel_order
    unless @order.pending? || @order.failed?
      redirect_to order_path(@order), alert: "Only pending or failed orders can be canceled."
      return
    end

    if @order.transition_to("cancelled")
      redirect_to order_path(@order), notice: "Order canceled. Payment cannot be restarted."
    else
      redirect_to order_path(@order), alert: "Could not cancel this order."
    end
  end

  def payment_success
    unless payment_start_allowed?
      redirect_to order_path(@order), notice: "Order payment is already finalized."
      return
    end

    session_id = stripe_session_id
    if session_id.blank?
      redirect_to order_path(@order), alert: "Missing Stripe session confirmation."
      return
    end

    stripe_session = Stripe::Checkout::Session.retrieve(session_id)
    unless stripe_session_matches_order?(stripe_session)
      redirect_to order_path(@order), alert: "Stripe confirmation did not match this order."
      return
    end

    if stripe_session.payment_status == "paid" && @order.transition_to("paid")
      payment_intent_id = stripe_payment_intent_id(stripe_session)
      @order.update!(
        stripe_payment_id: payment_intent_id.presence || session_id,
        stripe_customer_id: stripe_session.customer
      )
      redirect_to order_path(@order), notice: "Payment confirmed and order marked as paid."
      return
    end

    redirect_to order_path(@order), alert: "Stripe did not confirm payment for this order."
  rescue Stripe::StripeError => e
    redirect_to order_path(@order), alert: "Unable to verify Stripe payment: #{e.message}"
  end

  def payment_cancel
    if @order.pending? && @order.transition_to("failed")
      redirect_to order_path(@order), alert: "Payment was canceled. Order marked failed so you can retry."
      return
    end

    redirect_to order_path(@order), alert: "Payment was canceled."
  end

  private

  def payment_start_allowed?
    @order.pending? || @order.failed?
  end

  def retry_throttled_for_failed_order?
    @order.failed? && failed_retry_throttled?(@order)
  end

  def stripe_session_id
    Array(params[:session_id]).first.to_s
  end

  def stripe_session_matches_order?(stripe_session)
    stripe_session.metadata&.order_id.to_s == @order.id.to_s
  end

  def stripe_payment_intent_id(stripe_session)
    raw_payment_intent = Array(stripe_session.payment_intent).first
    return raw_payment_intent.id.to_s if raw_payment_intent.respond_to?(:id)

    raw_payment_intent.to_s
  end

  def failed_retry_throttled?(order)
    cache_key = "order:#{order.id}:failed_retry_attempts"
    attempts = Rails.cache.read(cache_key).to_i
    return true if attempts >= FAILED_RETRY_LIMIT

    Rails.cache.write(cache_key, attempts + 1, expires_in: FAILED_RETRY_WINDOW)
    false
  end

  def checkout_profile_params
    params.require(:checkout).permit(:address, :city, :postal_code, :province_id)
  end

  def cart_hash
    session[:cart] || {}
  end

  def build_checkout_items
    items = []

    cart_hash.each do |product_id, quantity|
      product = Product.find_by(id: product_id)
      next if product.blank?

      quantity = quantity.to_i
      next if quantity <= 0

      unit_price_cents = (product.price.to_d * 100).round
      line_total_cents = unit_price_cents * quantity

      items << {
        product: product,
        quantity: quantity,
        unit_price_cents: unit_price_cents,
        line_total_cents: line_total_cents
      }
    end

    items
  end

  def prepare_checkout(raw_profile)
    @checkout_items = build_checkout_items
    if @checkout_items.empty?
      redirect_to cart_path, alert: "Your cart is empty."
      return false
    end

    @subtotal_cents = @checkout_items.sum { |item| item[:line_total_cents] }

    @checkout_profile = normalize_checkout_profile(raw_profile)
    @province_options = Province.order(:name)
    province = Province.find_by(id: @checkout_profile[:province_id])
    @profile_complete = profile_complete?(province)

    gst_rate = province&.gst_rate.to_d
    pst_rate = province&.pst_rate.to_d
    hst_rate = province&.hst_rate.to_d

    @tax_rate = gst_rate + pst_rate + hst_rate
    @tax_cents = (@subtotal_cents * @tax_rate).round
    @total_cents = @subtotal_cents + @tax_cents

    @shipping_address_snapshot = shipping_address_snapshot(@checkout_profile)
    @province_snapshot = province_snapshot
    true
  end

  def default_checkout_profile
    {
      address: current_user.address.to_s,
      city: current_user.city.to_s,
      postal_code: current_user.postal_code.to_s,
      province_id: current_user.province_id
    }
  end

  def normalize_checkout_profile(raw_profile)
    profile = raw_profile || {}

    {
      address: profile[:address].to_s.strip,
      city: profile[:city].to_s.strip,
      postal_code: profile[:postal_code].to_s.strip,
      province_id: profile[:province_id].presence
    }
  end

  def profile_complete?(province)
    @checkout_profile[:address].present? &&
      @checkout_profile[:city].present? &&
      @checkout_profile[:postal_code].present? &&
      province.present?
  end

  def shipping_address_snapshot(profile)
    "#{profile[:address]}, #{profile[:city]}, #{profile[:postal_code]}"
  end

  def province_snapshot
    Province.find_by(id: @checkout_profile[:province_id])&.name
  end

  def stock_unavailable_item
    @checkout_items.find { |item| item[:quantity] > item[:product].stock.to_i }
  end

  def create_pending_order_from_checkout!
    order = nil
    item_tax_rate = @tax_rate.to_d.round(4)

    ActiveRecord::Base.transaction do
      order = current_user.orders.create!(
        status: "pending",
        total_cents: @total_cents,
        tax_amount_cents: @tax_cents,
        shipping_address: shipping_address_snapshot(@checkout_profile),
        province_snapshot: province_snapshot
      )

      @checkout_items.each do |item|
        order.order_items.create!(
          product: item[:product],
          quantity: item[:quantity],
          unit_price_cents: item[:unit_price_cents],
          tax_rate: item_tax_rate
        )
        item[:product].update!(stock: item[:product].stock - item[:quantity])
      end
    end

    order
  end

  def set_order
    @order = current_user.orders.includes(order_items: :product).find(params[:id])
  end

  def handle_order_not_found
    redirect_to orders_path, alert: "Order not found."
  end
end
