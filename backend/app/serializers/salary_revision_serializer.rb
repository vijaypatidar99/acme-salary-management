# 201 body of POST /employees/:id/salary_revisions (docs/api-contracts.md §3).
class SalaryRevisionSerializer
  def self.call(result)
    {
      employee_id: result.employee.id,
      current_salary: SalaryRecordSerializer.call(result.current_salary),
      previous_salary: SalaryRecordSerializer.call(result.previous_salary),
      reporting_currency: Compensation::REPORTING_CURRENCY
    }
  end
end
