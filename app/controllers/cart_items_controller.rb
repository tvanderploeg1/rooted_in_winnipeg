class CartItemsController < ApplicationController
  def create
    product = Product.find(params.require(:product_id))
    session[:cart] ||= {}
    session[:cart][product.id.to_s] ||= 0
    session[:cart][product.id.to_s] += 1

    redirect_back fallback_location: products_path, notice: "#{product.display_common_name} added to cart."
  end

  def destroy
    product_id = params.require(:id).to_s
    session[:cart] ||= {}
    session[:cart].delete(product_id)

    redirect_to cart_path, notice: "Item removed from cart."
  end

  def update
    product_id = params.require(:id).to_s
    quantity = params.require(:quantity).to_i

    session[:cart] ||= {}

    if quantity <= 0
      session[:cart].delete(product_id)
      redirect_to cart_path, notice: "Item removed from cart."
    else
      session[:cart][product_id] = quantity
      redirect_to cart_path, notice: "Cart quantity updated."
    end
  end
end
