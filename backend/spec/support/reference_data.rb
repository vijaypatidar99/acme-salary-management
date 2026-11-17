# Deterministic reference rows shared by service, request and query specs: four currencies with the
# illustrative rates of docs/domain-decisions.md §3.2, valid from before any test record.
module ReferenceFixtures
  RATES = { "USD" => "1.00000000", "EUR" => "1.08000000", "GBP" => "1.27000000", "INR" => "0.01200000" }.freeze
  NAMES = { "USD" => "US Dollar", "EUR" => "Euro", "GBP" => "Pound Sterling", "INR" => "Indian Rupee" }.freeze
  RATE_FLOOR = Date.new(2020, 1, 1)

  def create_currencies_and_rates
    RATES.each do |code, rate|
      Currency.find_or_create_by!(code: code) { |c| c.name = NAMES.fetch(code) }
      ExchangeRate.find_or_create_by!(from_currency: code, to_currency: "USD", effective_on: RATE_FLOOR) do |r|
        r.rate = BigDecimal(rate)
      end
    end
  end

  def create_country(code, name)
    Country.find_or_create_by!(code: code) { |c| c.name = name }
  end

  def create_department(name)
    Department.find_or_create_by!(name: name)
  end
end

RSpec.configure { |config| config.include ReferenceFixtures }
