class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: :show

  def new
    if cart_hash.blank?
      redirect_to cart_path, alert: "Your cart is empty."
      return
    end

    missing_fields = required_profile_fields.select { |field| current_user.public_send(field).blank? }
    if missing_fields.any?
      redirect_to account_path, alert: "Please complete your profile before checkout."
      return
    end

    @checkout_items = build_checkout_items
    if @checkout_items.empty?
      redirect_to cart_path, alert: "Your cart is empty."
      return
    end

    @subtotal_cents = @checkout_items.sum { |item| item[:line_total_cents] }

    province = current_user.province
    gst_rate = province&.gst_rate.to_d
    pst_rate = province&.pst_rate.to_d
    hst_rate = province&.hst_rate.to_d
    @tax_rate = gst_rate + pst_rate + hst_rate

    @tax_cents = (@subtotal_cents * @tax_rate).round
    @total_cents = @subtotal_cents + @tax_cents

    @shipping_address_snapshot = "#{current_user.address}, #{current_user.city}, #{current_user.postal_code}"
    @province_snapshot = province&.name
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

  def required_profile_fields
    [ :full_name, :address, :city, :postal_code, :province ]
  end

  def set_order
    @order = current_user.orders.find(params[:id])
  end
end
