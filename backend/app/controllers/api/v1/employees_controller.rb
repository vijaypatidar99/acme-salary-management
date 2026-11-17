module Api
  module V1
    class EmployeesController < ApplicationController
      def index
        page = Employees::Directory.new(params).page
        render json: {
          data: page.records.map { |employee| EmployeeSerializer.list_item(employee) },
          meta: { page: page.page, per_page: page.per_page, total_count: page.total_count,
                  total_pages: page.total_pages, reporting_currency: Compensation::REPORTING_CURRENCY }
        }
      end

      def show
        employee = Employee.includes(:department, :country).find(employee_id_param)
        history = employee.salary_records.newest_first.to_a
        render json: { data: EmployeeSerializer.detail(employee, history) }
      end

      # Same filters, sort and direction as the directory; paging is ignored and every row is streamed.
      def export
        directory = Employees::Directory.new(params, paginated: false) # validates before streaming starts
        response.headers["Content-Type"] = "text/csv; charset=utf-8"
        response.headers["Content-Disposition"] = %(attachment; filename="employees-#{Time.now.utc.strftime('%Y%m%d')}.csv")
        self.response_body = Employees::CsvExport.new(directory).each_line
      end
    end
  end
end
