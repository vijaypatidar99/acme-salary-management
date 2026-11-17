# Money and rates leave the API as decimal strings with a fixed number of decimals ("85000.00").
# BigDecimal#to_s("F") drops trailing zeros and Kernel#format goes through Float, so pad by hand.
module DecimalString
  module_function

  def call(value, scale: 2)
    return if value.nil?

    whole, fraction = BigDecimal(value.to_s).round(scale, :half_up).to_s("F").split(".")
    scale.zero? ? whole : "#{whole}.#{fraction.to_s.ljust(scale, '0')}"
  end
end
