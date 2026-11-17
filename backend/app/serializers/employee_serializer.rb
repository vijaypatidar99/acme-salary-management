# JSON shapes for employees (docs/api-contracts.md §1 and §2).
module EmployeeSerializer
  module_function

  # A directory row. The employee comes from Employees::Directory, which selects the country and
  # department names and the current salary (with its annual values computed in SQL) alongside it.
  def list_item(employee)
    base(employee).merge(
      department: { id: employee.department_id, name: employee["department_name"] },
      country: { code: employee.country_code, name: employee["country_name"] },
      current_salary: current_salary_summary(employee)
    )
  end

  # A single employee with the complete history, newest first. `history` is that list of records.
  def detail(employee, history)
    current = history.find(&:current?)
    base(employee).merge(
      department: { id: employee.department_id, name: employee.department.name },
      country: { code: employee.country_code, name: employee.country.name },
      terminated_on: employee.terminated_on&.iso8601,
      can_revise_salary: employee.can_revise_salary?,
      current_salary: current && SalaryRecordSerializer.call(current),
      salary_history: history.map { |record| SalaryRecordSerializer.call(record) },
      reporting_currency: Compensation::REPORTING_CURRENCY
    )
  end

  def base(employee)
    {
      id: employee.id,
      employee_number: employee.employee_number,
      first_name: employee.first_name,
      last_name: employee.last_name,
      job_title: employee.job_title,
      job_level: employee.job_level,
      employment_status: employee.employment_status,
      hired_on: employee.hired_on.iso8601
    }
  end

  def current_salary_summary(employee)
    return if employee["salary_record_id"].nil?

    {
      id: employee["salary_record_id"],
      amount: DecimalString.call(employee["salary_amount"]),
      currency: employee["salary_currency"],
      pay_frequency: employee["salary_pay_frequency"],
      annual_base_local: DecimalString.call(employee["annual_base_local"]),
      annual_base_reporting: DecimalString.call(employee["annual_base_reporting"]),
      effective_from: Timestamp.call(employee["salary_effective_from"])
    }
  end
end
