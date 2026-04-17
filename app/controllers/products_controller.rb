class ProductsController < ApplicationController
  before_action :set_product, only: [:show]

  def index
    grouped_products = Product
      .includes(:category, image_attachment: :blob)
      .order(:name, :id)
      .group_by { |product| product.name.to_s.downcase }

    @products = grouped_products.values.map do |variants|
      variants.find { |variant| variant.image.attached? } || variants.first
    end

    @products = @products.sort_by { |product| product.display_common_name.downcase }
  end

  def show
    @scientific_names = Product
      .where("LOWER(name) = ?", @product.name.downcase)
      .where.not(scientific_name: [nil, ""])
      .distinct
      .order(:scientific_name)
      .pluck(:scientific_name)
  end

  private

  def set_product
    @product = Product.includes(:category).find(params[:id])
  end
end
