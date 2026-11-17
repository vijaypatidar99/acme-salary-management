class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string :employee_number, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :job_title, null: false
      t.integer :job_level, limit: 2, null: false
      t.references :department, null: false, foreign_key: true, index: { name: "index_employees_on_department_id" }
      t.string :country_code, limit: 2, null: false
      t.string :employment_status, null: false
      t.date :hired_on, null: false
      t.date :terminated_on
      t.timestamps

      t.index :employee_number, unique: true, name: "index_employees_on_employee_number"
      t.index :country_code, name: "index_employees_on_country_code"
      t.check_constraint "job_level BETWEEN 1 AND 7", name: "employees_job_level_range"
      t.check_constraint "employment_status IN ('active', 'on_leave', 'terminated')", name: "employees_status_values"
      # DR-09: terminated_on is set if and only if the employee is terminated, and not before hiring.
      t.check_constraint "(employment_status = 'terminated') = (terminated_on IS NOT NULL) " \
                         "AND (terminated_on IS NULL OR terminated_on >= hired_on)",
                         name: "employees_terminated_on_rule"
    end

    add_foreign_key :employees, :countries, column: :country_code, primary_key: :code, name: "fk_employees_country_code"
  end
end
