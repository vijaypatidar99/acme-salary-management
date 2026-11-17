FactoryBot.define do
  factory :country do
    sequence(:code) { |n| ("AA".."ZZ").to_a[n % 676] }
    sequence(:name) { |n| "Country #{n}" }
  end

  factory :department do
    sequence(:name) { |n| "Department #{n}" }
  end

  factory :currency do
    sequence(:code) { |n| ("AAA".."ZZZ").to_a[n % 17_576] }
    sequence(:name) { |n| "Currency #{n}" }
  end

  factory :exchange_rate do
    from_currency { "EUR" }
    to_currency { "USD" }
    rate { BigDecimal("1.08") }
    effective_on { Date.new(2020, 1, 1) }
  end
end
