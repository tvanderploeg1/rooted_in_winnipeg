class CartsController < ApplicationController
  def show
    cart_hash = session[:cart] || {}
    @cart_items = []
    @subtotal = 0.to_d

    cart_hash.each do |product_id, quantity|
      product = Product.find_by(id: product_id)
      next if product.blank?

      quantity = quantity.to_i
      next if quantity <= 0

      line_total = product.price * quantity

      @cart_items << { product: product, quantity: quantity, line_total: line_total }
      @subtotal += line_total
    end
  end
end
