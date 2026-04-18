class ProductsController < ApplicationController
  before_action :set_product, only: [ :show ]

  def index
    @categories = Category.order(:name)

    @products = Product
      .includes(:category, image_attachment: :blob)
      .order(:name, :id)

    if params[:query].present?
      query = "%#{params[:query].strip.downcase}%"
      @products = @products.where(
        "LOWER(name) LIKE ? OR LOWER(scientific_name) LIKE ? OR LOWER(description) LIKE ?",
        query, query, query
      )
    end

    if params[:category_id].present?
      @products = @products.where(category_id: params[:category_id])
    end

    @products = @products.page(params[:page]).per(24)
  end

  def show
    @scientific_names = Product
      .where("LOWER(name) = ?", @product.name.downcase)
      .where.not(scientific_name: [ nil, "" ])
      .distinct
      .order(:scientific_name)
      .pluck(:scientific_name)
  end

  private

  def set_product
    @product = Product.includes(:category).find(params[:id])
  end
end
