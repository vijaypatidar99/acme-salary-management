class Employee < ApplicationRecord
  JOB_LEVELS = (1..7).to_a.freeze

  belongs_to :department
  belongs_to :country, foreign_key: :country_code, primary_key: :code, inverse_of: :employees
  has_many :salary_records, dependent: :restrict_with_exception
  has_one :current_salary_record, -> { where(effective_to: nil) }, class_name: "SalaryRecord", inverse_of: :employee

  # DR-03: only `active` employees count in compensation analytics; `terminated` cannot be revised.
  enum :employment_status, { active: "active", on_leave: "on_leave", terminated: "terminated" }, validate: true

  validates :employee_number, presence: true, uniqueness: true
  validates :first_name, :last_name, :job_title, :hired_on, presence: true
  validates :job_level, inclusion: { in: JOB_LEVELS }
  validate :terminated_on_matches_status

  # DR-03: `on_leave` may be revised; `terminated` may not. (Analytics inclusion is a different rule.)
  def can_revise_salary?
    !terminated?
  end

  private

  def terminated_on_matches_status
    if terminated?
      errors.add(:terminated_on, "can't be blank") if terminated_on.blank?
    elsif terminated_on.present?
      errors.add(:terminated_on, "must be blank unless the employee is terminated")
    end
    errors.add(:terminated_on, "can't be before hired_on") if terminated_on && hired_on && terminated_on < hired_on
  end
end
