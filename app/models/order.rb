class Order < ApplicationRecord
  ALLOWED_STATUS_TRANSITIONS = {
    "pending" => %w[paid failed],
    "paid" => %w[shipped],
    "shipped" => [],
    "failed" => []
  }.freeze

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
  validate :status_transition_is_allowed, if: :will_save_change_to_status?

  def can_transition_to?(new_status)
    ALLOWED_STATUS_TRANSITIONS.fetch(status.to_s, []).include?(new_status.to_s)
  end

  def transition_to!(new_status)
    return true if status.to_s == new_status.to_s

    unless can_transition_to?(new_status)
      errors.add(:status, "cannot transition from #{status} to #{new_status}")
      return false
    end

    update(status: new_status)
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

  private

  def status_transition_is_allowed
    previous_status = status_in_database
    return if previous_status.blank?
    return if previous_status.to_s == status.to_s

    allowed = ALLOWED_STATUS_TRANSITIONS.fetch(previous_status.to_s, [])
    return if allowed.include?(status.to_s)

    errors.add(:status, "cannot transition from #{previous_status} to #{status}")
  end
end
