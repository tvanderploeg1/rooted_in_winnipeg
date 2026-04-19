class Product < ApplicationRecord
  belongs_to :category

  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items

  has_one_attached :image

  validates :name, presence: true, uniqueness: { scope: :scientific_name }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :perenual_id, numericality: { only_integer: true }, uniqueness: true, allow_nil: true

  def display_common_name
    name.to_s.titleize
  end

  def display_name
    return display_common_name if scientific_name.blank?

    "#{display_common_name} (#{scientific_name})"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      category_id created_at description family genus id name perenual_id
      price scientific_name stock sunlight updated_at watering
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[category image_attachment image_blob order_items orders]
  end
end
