class Currency < ApplicationRecord
  self.primary_key = "code"

  has_many :salary_records, foreign_key: :currency_code, inverse_of: :currency, dependent: :restrict_with_exception

  validates :code, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :name, presence: true
end
