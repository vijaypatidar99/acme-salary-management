require "rails_helper"

RSpec.describe SalaryRecord do
  it "is valid with the factory defaults" do
    expect(build(:salary_record)).to be_valid
  end

  describe "amount (DR-11)" do
    it "rejects excess decimals before the column can round them" do
      [ "10.005", BigDecimal("10.005") ].each do |amount|
        record = build(:salary_record, amount: amount)
        expect(record).not_to be_valid
        expect(record.errors[:amount]).to be_present
      end
    end

    it "rejects malformed string amounts and binary floating-point input" do
      [ "1e5", "007", " 10", 10.5 ].each do |amount|
        expect(build(:salary_record, amount: amount)).not_to be_valid, amount.inspect
      end
    end

    it "must be positive" do
      expect(build(:salary_record, amount: 0)).not_to be_valid
      expect(build(:salary_record, amount: -1)).not_to be_valid
    end

    it "accepts the maximum and rejects anything above it" do
      expect(build(:salary_record, amount: SalaryAmount::MAX)).to be_valid
      expect(build(:salary_record, amount: SalaryAmount::MAX + BigDecimal("0.01"))).not_to be_valid
    end
  end

  it "requires a positive fx_rate" do
    expect(build(:salary_record, fx_rate: 0)).not_to be_valid
  end

  it "accepts only monthly and annual pay frequencies" do
    expect(build(:salary_record, pay_frequency: "monthly")).to be_valid
    expect(build(:salary_record, pay_frequency: "weekly")).not_to be_valid
  end

  it "requires a reason of at most 255 characters" do
    expect(build(:salary_record, reason: " ")).not_to be_valid
    expect(build(:salary_record, reason: "a" * 255)).to be_valid
    expect(build(:salary_record, reason: "a" * 256)).not_to be_valid
  end

  it "trims the reason on creation, before validating its length" do
    record = create(:salary_record, reason: "  #{'a' * 255}  ")
    expect(record.reload.reason).to eq("a" * 255)
  end

  it "rejects NUL characters in a reason before PostgreSQL rejects the string" do
    expect(build(:salary_record, reason: "review\0text")).not_to be_valid
  end

  it "requires effective_to to be later than effective_from" do
    from = Time.utc(2025, 1, 1)
    expect(build(:salary_record, effective_from: from, effective_to: from)).not_to be_valid
    expect(build(:salary_record, effective_from: from, effective_to: from - 1)).not_to be_valid
    expect(build(:salary_record, effective_from: from, effective_to: from + 1)).to be_valid
  end

  it "requires an existing currency" do
    expect(build(:salary_record, currency: nil)).not_to be_valid
  end

  describe "append-only history" do
    let!(:record) { create(:salary_record) }

    %i[amount currency_code pay_frequency fx_rate effective_from reason employee_id].each do |attribute|
      it "refuses to change #{attribute} after creation" do
        value = { amount: 1, currency_code: "EUR", pay_frequency: "monthly", fx_rate: 2,
                  effective_from: Time.utc(2020, 1, 1), reason: "edited", employee_id: 0 }.fetch(attribute)
        expect { record.update!(attribute => value) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
      end
    end

    it "allows closing the record by setting effective_to" do
      record.update!(effective_to: record.effective_from + 1.day)
      expect(record.reload).not_to be_current
    end

    it "refuses to reopen or move the end of a closed record" do
      record.update!(effective_to: record.effective_from + 1.day)
      ending = record.effective_to

      [ nil, ending + 1.day ].each do |value|
        expect { record.update!(effective_to: value) }.to raise_error(ActiveRecord::RecordInvalid)
        expect(record.reload.effective_to).to eq(ending)
      end
    end

    it "refuses to destroy salary history" do
      expect { record.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(described_class.exists?(record.id)).to be(true)
    end
  end

  describe "scopes and helpers" do
    it "separates current from closed records and lists newest first" do
      employee = create(:employee)
      old = create(:salary_record, :closed, employee: employee)
      current = create(:salary_record, employee: employee, effective_from: old.effective_to)

      expect(described_class.current).to contain_exactly(current)
      expect(employee.salary_records.newest_first.to_a).to eq([ current, old ])
      expect(current).to be_current
    end

    it "computes annual values with the shared calculation" do
      record = build(:salary_record, amount: "250000.00", pay_frequency: "monthly", fx_rate: "0.012")
      expect(record.annual_local).to eq(BigDecimal("3000000.00"))
      expect(record.annual_reporting).to eq(BigDecimal("36000.00"))
    end
  end
end
