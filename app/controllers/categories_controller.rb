class CategoriesController < ApplicationController
  before_action :set_category, only: [:show]

  def show
    @products = @category.products.includes(:image_attachment).order(:name, :id)
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end
end