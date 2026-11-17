# The one definition of how a salary record becomes an annual local amount and an annual USD
# amount (docs/domain-decisions.md §2 and §4). Ruby and SQL implement the same rules and are kept
# in step by spec/models/compensation_spec.rb (parity spec).
#
#   annual_local     = amount × 12 (monthly) | amount × 1 (annual)          — exact at 2 dp
#   annual_reporting = ROUND(annual_local × fx_rate, 2)                      — half away from zero
#
# Annualize first, convert once, round once per employee (DR-06, working default: pending approval),
# then aggregate the rounded values. All arithmetic is BigDecimal / PostgreSQL numeric, never Float.
module Compensation
  REPORTING_CURRENCY = "USD".freeze
  PERIODS_PER_YEAR = { "monthly" => 12, "annual" => 1 }.freeze
  REPORTING_SCALE = 2

  module_function

  def annual_local(amount, pay_frequency)
    periods = PERIODS_PER_YEAR.fetch(pay_frequency.to_s)
    BigDecimal(amount.to_s) * periods
  end

  def annual_reporting(amount, pay_frequency, fx_rate)
    (annual_local(amount, pay_frequency) * BigDecimal(fx_rate.to_s)).round(REPORTING_SCALE, :half_up)
  end

  # SQL twins of the methods above. `table` is the alias of the salary_records table in the query.
  def annual_local_sql(table = "salary_records")
    "(#{table}.amount * CASE #{table}.pay_frequency WHEN 'monthly' THEN 12 WHEN 'annual' THEN 1 END)"
  end

  def annual_reporting_sql(table = "salary_records")
    "ROUND(#{annual_local_sql(table)} * #{table}.fx_rate, #{REPORTING_SCALE})"
  end
end
