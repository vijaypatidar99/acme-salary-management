# Lookup source for FX rates (DR-05). 1 unit of from_currency = rate units of to_currency; only
# `to_currency = USD` is used. The rate in force when a salary record is created is copied onto
# that record (salary_records.fx_rate), so editing this table never changes past records.
class ExchangeRate < ApplicationRecord
  belongs_to :from, class_name: "Currency", foreign_key: :from_currency, primary_key: :code, inverse_of: false
  belongs_to :to, class_name: "Currency", foreign_key: :to_currency, primary_key: :code, inverse_of: false

  validates :rate, numericality: { greater_than: 0 }
  validates :effective_on, presence: true
  validates :effective_on, uniqueness: { scope: %i[from_currency to_currency] }
  validate :identity_rate_is_one

  # The row for `currency → USD` with the greatest effective_on on or before `date`, or nil.
  # A missing rate is never defaulted to 1; callers must treat nil as an error.
  def self.lookup(currency_code, on:)
    where(from_currency: currency_code, to_currency: Compensation::REPORTING_CURRENCY)
      .where(effective_on: ..on.to_date)
      .order(effective_on: :desc)
      .first
  end

  private

  def identity_rate_is_one
    errors.add(:rate, "must be 1 when converting a currency to itself") if from_currency == to_currency && rate != 1
  end
end
