class Category < ApplicationRecord
  has_many :products, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name updated_at]
  end
  def self.ransackable_associations(_auth_object = nil)
    %w[products]
  end
end
