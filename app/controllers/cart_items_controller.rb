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
end
