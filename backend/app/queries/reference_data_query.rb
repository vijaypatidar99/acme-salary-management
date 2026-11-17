# Option lists for the SPA's filters and revision form, read from the database and the model constants
# so nothing is hard-coded in a controller (docs/api-contracts.md §6, DR-14).
class ReferenceDataQuery
  def self.call(on: Time.now.utc.to_date)
    new(on).call
  end

  def initialize(date)
    @date = date
  end

  def call
    {
      reporting_currency: Compensation::REPORTING_CURRENCY,
      countries: Country.order(:name).pluck(:code, :name).map { |code, name| { code: code, name: name } },
      departments: Department.order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } },
      currencies: currencies,
      employment_statuses: Employee.employment_statuses.keys,
      pay_frequencies: SalaryRecord::PAY_FREQUENCIES,
      job_levels: Employee::JOB_LEVELS,
      low_sample_threshold: Analytics::Summary::LOW_SAMPLE_THRESHOLD
    }
  end

  private

  # has_rate: a usable currency → USD rate exists on or before today (UTC). USD qualifies through its
  # identity row. The revision endpoint re-validates against the revision timestamp's own date.
  def currencies
    has_rate = Currency.sanitize_sql_array([
      "EXISTS (SELECT 1 FROM exchange_rates r WHERE r.from_currency = currencies.code " \
      "AND r.to_currency = ? AND r.effective_on <= ?)", Compensation::REPORTING_CURRENCY, @date
    ])
    Currency.order(:code).select("currencies.code, currencies.name, #{has_rate} AS has_rate")
            .map { |currency| { code: currency.code, name: currency.name, has_rate: currency.has_rate } }
  end
end
