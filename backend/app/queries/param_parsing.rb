# Strict query-parameter parsing shared by the directory, the CSV export and the analytics summary.
# Anything malformed or unknown raises DomainError "invalid_parameter" (HTTP 400) naming the parameter,
# rather than being silently ignored (docs/api-contracts.md, Conventions).
module ParamParsing
  private

  def invalid_parameter!(name, message)
    raise DomainError.new("invalid_parameter", "#{name} #{message}", details: { name.to_s => [ message ] })
  end

  # nil when the parameter is absent or empty; arrays and hashes (q[]=x) are rejected.
  def string_param(params, name)
    value = params[name]
    return if value.nil?
    invalid_parameter!(name, "must be a string") unless value.is_a?(String)
    invalid_parameter!(name, "must not contain NUL characters") if value.include?("\0")

    value
  end

  def integer_param(params, name, range: nil, positive: false)
    value = string_param(params, name)
    return if value.nil?
    invalid_parameter!(name, "must be an integer") unless value.match?(/\A-?\d+\z/)

    number = Integer(value, 10)
    invalid_parameter!(name, "must be a positive integer") if positive && number < 1
    invalid_parameter!(name, "must be between #{range.min} and #{range.max}") if range && !range.cover?(number)
    number
  end

  # ISO alpha-2 code of an existing country.
  def country_param(params, name = :country)
    value = string_param(params, name)
    return if value.nil?

    Country.exists?(code: value) ? value : invalid_parameter!(name, "is not a known country code")
  end

  # Numeric id of an existing department.
  def department_param(params, name = :department)
    id = integer_param(params, name, positive: true)
    return if id.nil?

    Department.exists?(id: id) ? id : invalid_parameter!(name, "is not a known department")
  end
end
