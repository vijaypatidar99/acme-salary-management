require "rails_helper"

RSpec.describe "Reference models" do
  describe Country do
    it "needs a two-letter uppercase code and a name" do
      expect(build(:country, code: "IN", name: "India")).to be_valid
      expect(build(:country, code: "in")).not_to be_valid
      expect(build(:country, code: "IND")).not_to be_valid
      expect(build(:country, name: "")).not_to be_valid
    end

    it "uses the code as its primary key" do
      create(:country, code: "IN", name: "India")
      expect(described_class.find("IN").name).to eq("India")
    end
  end

  describe Currency do
    it "needs a three-letter uppercase code and a name" do
      expect(build(:currency, code: "INR", name: "Rupee")).to be_valid
      expect(build(:currency, code: "inr")).not_to be_valid
      expect(build(:currency, code: "IN")).not_to be_valid
      expect(build(:currency, name: nil)).not_to be_valid
    end
  end

  describe Department do
    it "needs a name" do
      expect(build(:department, name: "Engineering")).to be_valid
      expect(build(:department, name: " ")).not_to be_valid
    end

    it "cannot be deleted while it has employees" do
      employee = create(:employee)
      expect { employee.department.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end

  describe ExchangeRate do
    before { create_currencies_and_rates }

    it "is valid with a positive rate and a date" do
      expect(build(:exchange_rate, effective_on: Date.new(2021, 1, 1))).to be_valid
    end

    it "rejects a zero or negative rate" do
      expect(build(:exchange_rate, rate: 0, effective_on: Date.new(2021, 1, 1))).not_to be_valid
      expect(build(:exchange_rate, rate: -1, effective_on: Date.new(2021, 1, 1))).not_to be_valid
    end

    it "is unique per currency pair and date" do
      expect(build(:exchange_rate, effective_on: ReferenceFixtures::RATE_FLOOR)).not_to be_valid
    end

    it "requires an identity rate of exactly 1 when converting a currency to itself" do
      expect(build(:exchange_rate, from_currency: "USD", to_currency: "USD", rate: 2, effective_on: Date.new(2021, 1, 1))).not_to be_valid
    end

    describe ".lookup" do
      before { create(:exchange_rate, from_currency: "EUR", rate: BigDecimal("1.10"), effective_on: Date.new(2023, 1, 1)) }

      it "returns the row with the greatest effective_on on or before the date" do
        expect(described_class.lookup("EUR", on: Date.new(2022, 12, 31)).rate).to eq(BigDecimal("1.08"))
        expect(described_class.lookup("EUR", on: Date.new(2024, 6, 1)).rate).to eq(BigDecimal("1.10"))
      end

      it "treats the effective date as inclusive" do
        expect(described_class.lookup("EUR", on: Date.new(2023, 1, 1)).rate).to eq(BigDecimal("1.10"))
      end

      it "accepts a Time and uses its date" do
        expect(described_class.lookup("EUR", on: Time.utc(2023, 1, 1, 23, 59, 59, 999_999)).rate).to eq(BigDecimal("1.10"))
      end

      it "returns nil, never a default of 1, when no rate applies" do
        expect(described_class.lookup("EUR", on: Date.new(2019, 12, 31))).to be_nil
        expect(described_class.lookup("JPY", on: Date.new(2024, 1, 1))).to be_nil
      end
    end
  end
end
