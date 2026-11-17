# A business-rule failure with a stable, machine-readable code from docs/api-contracts.md. Services
# raise it; ApiErrorHandling turns it into the contract's error response. Raising inside a
# transaction rolls the whole transaction back.
class DomainError < StandardError
  STATUS_BY_CODE = {
    "invalid_parameter" => :bad_request,
    "invalid_request" => :bad_request,
    "unauthorized" => :unauthorized,
    "writes_disabled" => :forbidden,
    "not_found" => :not_found,
    "stale_salary_record" => :conflict,
    "revision_conflict" => :conflict,
    "employee_not_eligible" => :unprocessable_entity,
    "validation_failed" => :unprocessable_entity,
    "no_change" => :unprocessable_entity,
    "missing_exchange_rate" => :unprocessable_entity
  }.freeze

  attr_reader :code, :details

  def initialize(code, message, details: nil)
    raise ArgumentError, "unknown error code #{code.inspect}" unless STATUS_BY_CODE.key?(code)

    super(message)
    @code = code
    @details = details
  end

  def status
    STATUS_BY_CODE.fetch(code)
  end
end
