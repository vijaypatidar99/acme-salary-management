require "rails_helper"

RSpec.describe DecimalString do
  it "pads to the requested scale without going through Float" do
    expect(described_class.call(BigDecimal("85000"))).to eq("85000.00")
    expect(described_class.call(BigDecimal("0.012"), scale: 8)).to eq("0.01200000")
    expect(described_class.call("123456789012.35")).to eq("123456789012.35")
  end

  it "rounds half away from zero" do
    expect(described_class.call(BigDecimal("50000.005"))).to eq("50000.01")
  end

  it "returns nil for nil" do
    expect(described_class.call(nil)).to be_nil
  end
end
