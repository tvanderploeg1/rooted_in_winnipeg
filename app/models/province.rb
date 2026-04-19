class Province < ApplicationRecord
  has_many :users

  validates :name, :abbreviation, :gst_rate, :pst_rate, :hst_rate, presence: true
  validates :name, length: { maximum: 60 }
  validates :abbreviation, length: { is: 2 }, format: { with: /\A[A-Z]{2}\z/ }
  validates :abbreviation, uniqueness: true
  validates :gst_rate, :pst_rate, :hst_rate,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
