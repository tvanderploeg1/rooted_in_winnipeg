class StaticPagesController < ApplicationController
  def home
    @featured_products = Product.includes(:category).order("RANDOM()").limit(9)
  end

  def about
  end
end
