FactoryBot.define do
  factory :salary_record do
    employee
    currency { Currency.find_or_create_by!(code: "USD") { |c| c.name = "US Dollar" } }
    amount { BigDecimal("90000.00") }
    pay_frequency { "annual" }
    fx_rate { BigDecimal("1.00000000") }
    effective_from { Time.utc(2025, 1, 1) }
    effective_to { nil }
    reason { "Initial salary" }

    trait :closed do
      effective_to { Time.utc(2025, 6, 1) }
    end
  end
end
