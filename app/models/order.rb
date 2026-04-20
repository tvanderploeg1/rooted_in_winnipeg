class Order < ApplicationRecord
  belongs_to :user

  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  enum :status, { pending: "pending", paid: "paid", shipped: "shipped", failed: "failed" }

  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :shipping_address, :province_snapshot, presence: true
  validates :shipping_address, length: { maximum: 255 }
  validates :province_snapshot, length: { maximum: 80 }
  validates :total_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :tax_amount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def subtotal_cents
    total_cents.to_i - tax_amount_cents.to_i
  end

  def effective_tax_rate
    return 0.to_d unless subtotal_cents.positive?

    tax_amount_cents.to_d / subtotal_cents
  end
end
