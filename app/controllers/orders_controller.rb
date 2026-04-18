class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: :show

  def new
    return unless prepare_checkout
  end

  def create
    return unless prepare_checkout

    unavailable_item = @checkout_items.find { |item| item[:quantity] > item[:product].stock.to_i }
    if unavailable_item.present?
      redirect_to cart_path, alert: "Not enough stock for #{unavailable_item[:product].display_common_name}."
      return
    end

    order = nil

    ActiveRecord::Base.transaction do
      order = current_user.orders.create!(
        status: "pending",
        total_cents: @total_cents,
        tax_amount_cents: @tax_cents,
        shipping_address: shipping_address_snapshot,
        province_snapshot: province_snapshot
      )

      @checkout_items.each do |item|
        order.order_items.create!(
          product: item[:product],
          quantity: item[:quantity],
          unit_price_cents: item[:unit_price_cents]
        )

        item[:product].update!(stock: item[:product].stock - item[:quantity])
      end
    end

    session[:cart] = {}
    redirect_to order_path(order), notice: "Order created successfully."
  rescue ActiveRecord::RecordInvalid
    redirect_to checkout_path, alert: "Could not place order. Please try again."
  end

  def index
    @orders = current_user.orders.order(created_at: :desc)
  end

  def show
  end

  private

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

  def prepare_checkout
    @checkout_items = build_checkout_items
    if @checkout_items.empty?
      redirect_to cart_path, alert: "Your cart is empty."
      return false
    end

    @subtotal_cents = @checkout_items.sum { |item| item[:line_total_cents] }

    province = current_user.province
    gst_rate = province&.gst_rate.to_d
    pst_rate = province&.pst_rate.to_d
    hst_rate = province&.hst_rate.to_d

    @tax_rate = gst_rate + pst_rate + hst_rate
    @tax_cents = (@subtotal_cents * @tax_rate).round
    @total_cents = @subtotal_cents + @tax_cents

    @shipping_address_snapshot = shipping_address_snapshot
    @province_snapshot = province_snapshot
    true
  end

  def shipping_address_snapshot
    "#{current_user.address}, #{current_user.city}, #{current_user.postal_code}"
  end

  def province_snapshot
    current_user.province&.name
  end

  def set_order
    @order = current_user.orders.includes(order_items: :product).find(params[:id])
  end
end
