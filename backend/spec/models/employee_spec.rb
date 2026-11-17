require "rails_helper"

RSpec.describe Employee do
  it "is valid with the factory defaults" do
    expect(build(:employee)).to be_valid
  end

  it "requires a unique employee number" do
    create(:employee, employee_number: "ACME-00001")
    expect(build(:employee, employee_number: "ACME-00001")).not_to be_valid
  end

  it "requires names, title and hire date" do
    %i[first_name last_name job_title hired_on].each do |attribute|
      expect(build(:employee, attribute => nil)).not_to be_valid
    end
  end

  it "accepts job levels 1 to 7 only" do
    expect(build(:employee, job_level: 1)).to be_valid
    expect(build(:employee, job_level: 7)).to be_valid
    expect(build(:employee, job_level: 0)).not_to be_valid
    expect(build(:employee, job_level: 8)).not_to be_valid
  end

  describe "employment status" do
    it "accepts active, on_leave and terminated" do
      expect(build(:employee)).to be_valid
      expect(build(:employee, :on_leave)).to be_valid
      expect(build(:employee, :terminated)).to be_valid
    end

    it "rejects an unknown status with a validation error instead of raising" do
      employee = build(:employee, employment_status: "retired")
      expect(employee).not_to be_valid
      expect(employee.errors[:employment_status]).to be_present
    end
  end

  describe "terminated_on (DR-09)" do
    it "is required when terminated" do
      expect(build(:employee, employment_status: "terminated", terminated_on: nil)).not_to be_valid
    end

    it "must be blank when not terminated" do
      expect(build(:employee, terminated_on: Date.new(2025, 1, 1))).not_to be_valid
    end

    it "cannot precede the hire date" do
      expect(build(:employee, :terminated, hired_on: Date.new(2025, 6, 1), terminated_on: Date.new(2025, 1, 1))).not_to be_valid
    end
  end

  describe "#can_revise_salary? (DR-03)" do
    it "allows active and on_leave but not terminated" do
      expect(build(:employee).can_revise_salary?).to be(true)
      expect(build(:employee, :on_leave).can_revise_salary?).to be(true)
      expect(build(:employee, :terminated).can_revise_salary?).to be(false)
    end
  end

  describe "salary associations" do
    it "exposes the open record as the current salary and keeps the rest as history" do
      employee = create(:employee)
      old = create(:salary_record, :closed, employee: employee)
      current = create(:salary_record, employee: employee, effective_from: old.effective_to)

      expect(employee.current_salary_record).to eq(current)
      expect(employee.salary_records).to contain_exactly(old, current)
    end

    it "cannot be deleted while it has salary history" do
      record = create(:salary_record)
      expect { record.employee.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end
end
