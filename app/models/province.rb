class Province < ApplicationRecord
  has_many :users

  validates :name, :abbreviation, presence: true
  validates :abbreviation, uniqueness: true
  validates :gst_rate, :pst_rate, :hst_rate,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
            allow_nil: true
end
