class StaticPagesController < ApplicationController
  def home
    @featured_products = Product.order("RANDOM()").limit(9)
  end

  def about
  end
end
