# Validation of a salary amount as entered (docs/domain-decisions.md §4.3, DR-11).
#
# The API accepts the amount only as a decimal string. PostgreSQL numeric(14,2) would silently
# round a third decimal place, so the syntax is checked here before anything is written.
module SalaryAmount
  # DR-11: per-record limit on the *entered* amount, in the salary's own currency and pay frequency.
  MAX = BigDecimal("1000000000.00")
  FORMAT = /\A(0|[1-9][0-9]*)(\.[0-9]{1,2})?\z/

  module_function

  # The amount as a BigDecimal, or nil when the string does not match the accepted syntax.
  def parse(value)
    return unless value.is_a?(String) && FORMAT.match?(value)

    BigDecimal(value)
  end

  # Human-readable problems for the `amount` field; empty when the value is acceptable.
  def errors_for(value)
    return [ "can't be blank" ] if value.nil? || value.to_s.strip.empty?

    amount = parse(value)
    return [ "must be a decimal number with at most two decimal places" ] unless amount
    return [ "must be greater than 0" ] unless amount.positive?
    return [ "must be less than or equal to #{DecimalString.call(MAX)}" ] if amount > MAX

    []
  end
end
