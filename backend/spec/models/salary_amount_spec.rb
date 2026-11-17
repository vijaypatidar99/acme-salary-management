require "rails_helper"

RSpec.describe SalaryAmount do
  describe ".parse" do
    %w[1 0.5 85000 85000.5 85000.00 1000000000.00 0 0.00 10.05].each do |text|
      it "accepts #{text.inspect}" do
        expect(described_class.parse(text)).to eq(BigDecimal(text))
      end
    end

    [ "007", "1e5", "1E5", "-5", "+5", "1,000.00", " 1", "1 ", "10.005", "1.", ".5", "NaN", "Infinity", "", "abc", "1_000" ].each do |text|
      it "rejects #{text.inspect}" do
        expect(described_class.parse(text)).to be_nil
      end
    end

    it "rejects non-strings, including numbers" do
      expect(described_class.parse(85_000)).to be_nil
      expect(described_class.parse(nil)).to be_nil
    end
  end

  describe ".errors_for" do
    it "is empty for a valid amount, including the maximum" do
      expect(described_class.errors_for("1000000000.00")).to be_empty
    end

    it "reports blank, syntax, non-positive and over-maximum amounts" do
      expect(described_class.errors_for(nil)).to eq([ "can't be blank" ])
      expect(described_class.errors_for("1.234")).to eq([ "must be a decimal number with at most two decimal places" ])
      expect(described_class.errors_for("0.00")).to eq([ "must be greater than 0" ])
      expect(described_class.errors_for("1000000000.01")).to eq([ "must be less than or equal to 1000000000.00" ])
    end

    it "rejects values beyond the numeric(14,2) column capacity with the same maximum error" do
      expect(described_class.errors_for("1000000000000.00")).to eq([ "must be less than or equal to 1000000000.00" ])
    end
  end
end
