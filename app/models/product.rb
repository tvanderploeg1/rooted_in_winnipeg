class Product < ApplicationRecord
  belongs_to :category

  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items

  has_one_attached :image

  validates :name, presence: true, uniqueness: { scope: :scientific_name }
  validates :description, presence: true, length: { minimum: 20, maximum: 1200 }
  validates :scientific_name, length: { maximum: 120 }, allow_blank: true
  validates :watering, :sunlight, :family, :genus, presence: true, length: { maximum: 120 }
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
end
