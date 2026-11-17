class Country < ApplicationRecord
  self.primary_key = "code"

  has_many :employees, foreign_key: :country_code, inverse_of: :country, dependent: :restrict_with_exception

  validates :code, presence: true, format: { with: /\A[A-Z]{2}\z/ }
  validates :name, presence: true
end
