class Product < ApplicationRecord
  belongs_to :category

  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items

  has_one_attached :image

  validates :name, presence: true, uniqueness: { scope: :scientific_name }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :perenual_id, numericality: { only_integer: true }, uniqueness: true, allow_nil: true

  def display_name
    return name if scientific_name.blank?

    "#{name} (#{scientific_name})"
  end
end
