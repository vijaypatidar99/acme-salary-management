require "rails_helper"

RSpec.describe Analytics::Summary do
  before { create_demo_population }

  def summary(params = {})
    described_class.new(ActionController::Parameters.new(params)).call
  end

  it "returns the organization totals for active employees only" do
    organization = summary[:organization]

    expect(organization).to include(active_headcount: 4, total_annual_base_reporting: "186479.96",
                                    average_annual_base_reporting: "46619.99", median_annual_base_reporting: "39599.98")
  end

  it "exposes the documented low-sample threshold constant" do
    expect(described_class::LOW_SAMPLE_THRESHOLD).to eq(10)
  end

  it "validates filters with invalid_parameter errors" do
    expect { summary(country: "ZZ") }.to raise_error(DomainError) { |e| expect(e.code).to eq("invalid_parameter") }
    expect { summary(job_level: "9") }.to raise_error(DomainError) { |e| expect(e.details).to eq("job_level" => [ "must be between 1 and 7" ]) }
    expect { summary(department: "0") }.to raise_error(DomainError)
  end

  it "keeps every money value a decimal string" do
    data = summary
    amounts = [ data[:organization][:total_annual_base_reporting], data[:by_country].first[:total_annual_base_reporting],
                data[:by_country].first[:local_totals].first[:total_annual_base_local] ]

    expect(amounts).to all(match(/\A\d+\.\d{2}\z/))
  end
end
