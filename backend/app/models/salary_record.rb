# One row of append-only salary history for an employee, effective over [effective_from, effective_to).
# The record with effective_to NULL is the current one. The database prevents overlaps and multiple
# open records; the revision service and seed establish that every employee has an open record.
class SalaryRecord < ApplicationRecord
  PAY_FREQUENCIES = Compensation::PERIODS_PER_YEAR.keys.freeze

  belongs_to :employee
  belongs_to :currency, foreign_key: :currency_code, primary_key: :code, inverse_of: :salary_records

  # History is never edited: after creation only effective_to may change (when a successor closes it).
  attr_readonly :employee_id, :amount, :currency_code, :pay_frequency, :fx_rate, :effective_from, :reason

  before_validation :trim_reason, on: :create
  before_destroy :preserve_history

  validates :amount, numericality: { greater_than: 0, less_than_or_equal_to: SalaryAmount::MAX }
  validates :fx_rate, numericality: { greater_than: 0 }
  validates :pay_frequency, inclusion: { in: PAY_FREQUENCIES }
  validates :reason, presence: true, length: { maximum: 255 }
  validates :reason, format: { without: /\x00/, message: "must not contain NUL characters" }
  validates :effective_from, presence: true
  validate :effective_to_after_effective_from
  validate :amount_before_column_rounding
  validate :closed_interval_is_immutable, on: :update

  scope :current, -> { where(effective_to: nil) }
  scope :newest_first, -> { order(effective_from: :desc, id: :desc) }

  def current?
    effective_to.nil?
  end

  def annual_local
    Compensation.annual_local(amount, pay_frequency)
  end

  def annual_reporting
    Compensation.annual_reporting(amount, pay_frequency, fx_rate)
  end

  private

  def trim_reason
    self.reason = reason.strip if reason.is_a?(String)
  end

  def amount_before_column_rounding
    raw = amount_before_type_cast
    if raw.is_a?(String)
      SalaryAmount.errors_for(raw).each { |message| errors.add(:amount, message) }
    elsif !raw.is_a?(Integer) && !(raw.is_a?(BigDecimal) && raw.finite? && raw == raw.round(2))
      errors.add(:amount, "must be an exact decimal with at most two decimal places")
    end
  end

  def closed_interval_is_immutable
    if will_save_change_to_effective_to? && effective_to_in_database.present?
      errors.add(:effective_to, "cannot change once the salary record is closed")
    end
  end

  def preserve_history
    errors.add(:base, "Salary history cannot be deleted")
    throw :abort
  end

  def effective_to_after_effective_from
    return if effective_to.nil? || effective_from.nil?

    errors.add(:effective_to, "must be later than effective_from") unless effective_to > effective_from
  end
end
