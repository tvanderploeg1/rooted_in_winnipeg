class Order < ApplicationRecord
  ALLOWED_TRANSITIONS = {
    "pending" => %w[paid failed cancelled],
    "paid" => %w[shipped],
    "shipped" => [],
    "failed" => %w[paid cancelled],
    "cancelled" => []
  }.freeze

  belongs_to :user

  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  enum :status, { pending: "pending", paid: "paid", shipped: "shipped", failed: "failed", cancelled: "cancelled" }

  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :shipping_address, :province_snapshot, presence: true
  validates :shipping_address, length: { maximum: 255 }
  validates :province_snapshot, length: { maximum: 80 }
  validates :total_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :tax_amount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def can_transition_to?(next_status)
    ALLOWED_TRANSITIONS.fetch(status.to_s, []).include?(next_status.to_s)
  end

  def transition_to(next_status)
    return true if status.to_s == next_status.to_s

    unless can_transition_to?(next_status)
      errors.add(:status, "cannot transition from #{status} to #{next_status}")
      return false
    end

    update(status: next_status)
  end

  def subtotal_cents
    total_cents.to_i - tax_amount_cents.to_i
  end

  def effective_tax_rate
    return 0.to_d unless subtotal_cents.positive?

    tax_amount_cents.to_d / subtotal_cents
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at id province_snapshot shipping_address status
      tax_amount_cents total_cents updated_at user_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[order_items products user]
  end
end
