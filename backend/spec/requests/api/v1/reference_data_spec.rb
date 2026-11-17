require "rails_helper"

RSpec.describe "GET /api/v1/reference_data", type: :request do
  before do
    create_demo_population
    create_department("Operations")
    Currency.create!(code: "JPY", name: "Japanese Yen") # no exchange rate
    ExchangeRate.create!(from_currency: "GBP", to_currency: "USD", rate: "1.30", effective_on: Date.new(2999, 1, 1)) # future
  end

  it "returns every option list from the database and the model constants" do
    get "/api/v1/reference_data"

    expect(response).to have_http_status(:ok)
    data = json["data"]
    expect(data["reporting_currency"]).to eq("USD")
    expect(data["countries"]).to eq([ { "code" => "DE", "name" => "Germany" }, { "code" => "IN", "name" => "India" },
                                      { "code" => "US", "name" => "United States" } ])
    expect(data["departments"].map { |d| d["name"] }).to eq(%w[Engineering Operations Sales])
    expect(data["departments"].first.keys).to eq(%w[id name])
    expect(data["employment_statuses"]).to eq(%w[active on_leave terminated])
    expect(data["pay_frequencies"]).to eq(%w[monthly annual])
    expect(data["job_levels"]).to eq([ 1, 2, 3, 4, 5, 6, 7 ])
    expect(data["low_sample_threshold"]).to eq(10)
  end

  it "flags a currency as having a rate only when one is usable today (UTC)" do
    get "/api/v1/reference_data"

    rates = json["data"]["currencies"].to_h { |c| [ c["code"], c["has_rate"] ] }
    expect(rates).to eq("EUR" => true, "GBP" => true, "INR" => true, "JPY" => false, "USD" => true)
  end

  it "does not count a rate that only becomes effective in the future" do
    ExchangeRate.where(from_currency: "GBP", effective_on: ReferenceFixtures::RATE_FLOOR).delete_all

    get "/api/v1/reference_data"

    expect(json["data"]["currencies"].find { |c| c["code"] == "GBP" }["has_rate"]).to be(false)
  end
end
