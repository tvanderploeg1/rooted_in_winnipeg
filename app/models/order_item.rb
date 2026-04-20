class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :tax_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  def applicable_tax_rate(fallback_rate = 0.to_d)
    normalized_tax_rate = tax_rate.to_d
    normalized_tax_rate.positive? ? normalized_tax_rate : fallback_rate.to_d
  end

  def line_subtotal_cents
    unit_price_cents.to_i * quantity.to_i
  end

  def line_tax_cents(fallback_rate = 0.to_d)
    (line_subtotal_cents * applicable_tax_rate(fallback_rate)).round
  end

  def line_total_cents(fallback_rate = 0.to_d)
    line_subtotal_cents + line_tax_cents(fallback_rate)
  end
end
