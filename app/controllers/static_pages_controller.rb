class StaticPagesController < ApplicationController
  def home
    product_ids_with_images = Product.joins(:image_attachment).distinct.pluck(:id)
    featured_ids = product_ids_with_images.sample(9)
    @featured_products = Product.where(id: featured_ids)
  end

  def about
  end
end
