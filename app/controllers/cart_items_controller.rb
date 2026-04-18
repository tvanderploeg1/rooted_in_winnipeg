class CartItemsController < ApplicationController
  def create
    product = Product.find(params.require(:product_id))
    session[:cart] ||= {}

    product_key = product.id.to_s
    current_quantity = session[:cart][product_key].to_i

    if product.stock <= 0
      redirect_back fallback_location: products_path, alert: "#{product.display_common_name} is out of stock."
      return
    end

    if current_quantity >= product.stock
      redirect_back fallback_location: products_path, alert: "Only #{product.stock} in stock for #{product.display_common_name}."
      return
    end

    session[:cart][product_key] = current_quantity + 1
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
    product = Product.find_by(id: product_id)

    if product.blank?
      session[:cart].delete(product_id)
      redirect_to cart_path, alert: "Product no longer exists and was removed from your cart."
      return
    end

    if quantity <= 0
      session[:cart].delete(product_id)
      redirect_to cart_path, notice: "Item removed from cart."
    elsif quantity > product.stock
      session[:cart][product_id] = product.stock
      redirect_to cart_path, alert: "Only #{product.stock} in stock for #{product.display_common_name}. Quantity adjusted."
    else
      session[:cart][product_id] = quantity
      redirect_to cart_path, notice: "Cart quantity updated."
    end
  end
end
