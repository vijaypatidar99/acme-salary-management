module Analytics
  # Compensation overview for the active payroll population in USD (docs/api-contracts.md §4,
  # docs/domain-decisions.md §10). Everything is aggregated in PostgreSQL; Ruby only assembles JSON.
  #
  # Each employee's annual USD amount is computed once (Compensation SQL), already rounded to cents,
  # and totals, averages and medians are taken over those rounded values (DR-06 working default).
  # The median is exact numeric — ranked rows, middle row or mean of the two middle rows — and never
  # percentile_cont, which would coerce the money values to double precision (DR-15 working default).
  class Summary
    include ParamParsing

    # DR-08 (recommended value, approval pending): a group with fewer active employees is `low_sample`.
    LOW_SAMPLE_THRESHOLD = 10

    NOTES = [
      "Averages and medians are comparisons only, not pay-equity conclusions.",
      "Reporting-currency values use fixed illustrative exchange rates."
    ].freeze

    def initialize(params)
      @country = country_param(params)
      @department = department_param(params)
      @job_level = integer_param(params, :job_level, range: Employee::JOB_LEVELS.min..Employee::JOB_LEVELS.max)
    end

    def call
      {
        reporting_currency: Compensation::REPORTING_CURRENCY,
        filters: { country: @country, department: @department, job_level: @job_level },
        organization: organization,
        by_country: by_country,
        by_department: by_department,
        notes: NOTES
      }
    end

    private

    def organization
      stats = group_stats("1").first || {}
      { **metrics(stats), status_counts: status_counts }
    end

    def by_country
      names = Country.pluck(:code, :name).to_h
      locals = local_totals.group_by { |row| row["country_code"] }
      rows = group_stats("e.country_code").map do |row|
        { country: { code: row["g"], name: names.fetch(row["g"]) }, **metrics(row),
          local_totals: Array(locals[row["g"]]).map { |local| local_total(local) } }
      end
      ordered(rows) { |row| row[:country][:name] }
    end

    def by_department
      names = Department.pluck(:id, :name).to_h
      rows = group_stats("e.department_id").map do |row|
        { department: { id: row["g"], name: names.fetch(row["g"]) }, **metrics(row) }
      end
      ordered(rows) { |row| row[:department][:name] }
    end

    # Largest total first, then name. Totals are strings of identical scale, so compare as decimals.
    def ordered(rows, &name)
      rows.sort_by { |row| [ -BigDecimal(row[:total_annual_base_reporting]), name.call(row) ] }
    end

    def metrics(row)
      headcount = row["headcount"].to_i
      {
        active_headcount: headcount,
        low_sample: headcount < LOW_SAMPLE_THRESHOLD,
        total_annual_base_reporting: DecimalString.call(row["total"] || 0),
        average_annual_base_reporting: DecimalString.call(row["average"]),
        median_annual_base_reporting: DecimalString.call(row["median"])
      }
    end

    def local_total(row)
      { currency: row["currency_code"], active_headcount: row["headcount"].to_i,
        total_annual_base_local: DecimalString.call(row["total_local"]) }
    end

    # One row per group: headcount, total, average and exact median of the per-employee USD amounts.
    def group_stats(group_expression)
      select_rows(<<~SQL)
        WITH comp AS (
          SELECT e.id AS employee_id, #{group_expression} AS g, #{Compensation.annual_reporting_sql('s')} AS annual_reporting
          #{active_population_sql}
        ), ranked AS (
          SELECT g, annual_reporting,
                 ROW_NUMBER() OVER (PARTITION BY g ORDER BY annual_reporting, employee_id) AS rn,
                 COUNT(*) OVER (PARTITION BY g) AS n
          FROM comp
        )
        SELECT g, MAX(n) AS headcount, SUM(annual_reporting) AS total,
               ROUND(AVG(annual_reporting), 2) AS average,
               ROUND(AVG(annual_reporting) FILTER (WHERE rn IN ((n + 1) / 2, (n + 2) / 2)), 2) AS median
        FROM ranked GROUP BY g
      SQL
    end

    # Same-currency sums only: grouped by country AND the currency the salary is paid in.
    def local_totals
      select_rows(<<~SQL).sort_by { |row| [ -row["headcount"], row["currency_code"] ] }
        SELECT e.country_code, s.currency_code, COUNT(*) AS headcount, SUM(#{Compensation.annual_local_sql('s')}) AS total_local
        #{active_population_sql}
        GROUP BY e.country_code, s.currency_code
      SQL
    end

    # Counts every status (zeros included) for the filtered employee population, not only active ones.
    def status_counts
      counts = Employee.where(population_conditions).group(:employment_status).count
      Employee.employment_statuses.keys.index_with { |status| counts.fetch(status, 0) }
    end

    def active_population_sql
      <<~SQL
        FROM employees e
        JOIN salary_records s ON s.employee_id = e.id AND s.effective_to IS NULL
        WHERE e.employment_status = 'active' AND #{sanitized_filter_sql}
      SQL
    end

    def sanitized_filter_sql
      clauses = []
      clauses << Employee.sanitize_sql([ "e.country_code = ?", @country ]) if @country
      clauses << Employee.sanitize_sql([ "e.department_id = ?", @department ]) if @department
      clauses << Employee.sanitize_sql([ "e.job_level = ?", @job_level ]) if @job_level
      clauses.empty? ? "TRUE" : clauses.join(" AND ")
    end

    def population_conditions
      { country_code: @country, department_id: @department, job_level: @job_level }.compact
    end

    def select_rows(sql)
      Employee.connection.select_all(sql).to_a
    end
  end
end
