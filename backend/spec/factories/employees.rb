FactoryBot.define do
  factory :employee do
    sequence(:employee_number, 10_000) { |n| format("ACME-%05d", n) }
    first_name { "Asha" }
    last_name { "Rao" }
    job_title { "Senior Engineer" }
    job_level { 4 }
    department { Department.find_or_create_by!(name: "Engineering") }
    country { Country.find_or_create_by!(code: "IN") { |c| c.name = "India" } }
    employment_status { "active" }
    hired_on { Date.new(2020, 1, 1) }

    trait :on_leave do
      employment_status { "on_leave" }
    end

    trait :terminated do
      employment_status { "terminated" }
      terminated_on { Date.new(2025, 1, 1) }
    end
  end
end
