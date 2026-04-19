class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :province
  has_many :orders, dependent: :destroy

  POSTAL_CODE_REGEX = /\A[ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTV-Z][ -]?\d[ABCEGHJ-NPRSTV-Z]\d\z/i

  validates :full_name, :address, :city, :postal_code, :province, presence: true
  validates :full_name, length: { maximum: 120 }
  validates :address, length: { maximum: 200 }
  validates :city, length: { maximum: 120 }
  validates :postal_code, format: { with: POSTAL_CODE_REGEX, message: "must be a valid Canadian postal code" }
end
