class Order < ApplicationRecord
  belongs_to :user

  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  enum :status, { pending: "pending", paid: "paid", shipped: "shipped", failed: "failed" }

  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :total_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :tax_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
