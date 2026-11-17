module Employees
  # The employee directory: search, filters, allow-listed sort and pagination over employees joined to
  # their country, department and current salary record, in one query per page (no N+1). The CSV
  # export reuses this class so the list and the export can never disagree about filters or order.
  class Directory
    include ParamParsing

    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100
    MAX_QUERY_LENGTH = 100
    DEFAULT_SORT = "employee_number".freeze

    # Sort keys → SQL columns. Only these strings ever reach ORDER BY.
    SORT_COLUMNS = {
      "employee_number" => [ "employees.employee_number" ],
      "name" => [ "employees.last_name", "employees.first_name" ],
      "country" => [ "countries.name" ],
      "department" => [ "departments.name" ],
      "job_level" => [ "employees.job_level" ],
      "hired_on" => [ "employees.hired_on" ],
      "status" => [ "employees.employment_status" ],
      "annual_base_reporting" => [ Compensation.annual_reporting_sql ]
    }.freeze

    CURRENT_SALARY_JOIN = "LEFT JOIN salary_records ON salary_records.employee_id = employees.id " \
                          "AND salary_records.effective_to IS NULL".freeze

    SELECTED_COLUMNS = [
      "employees.*",
      "countries.name AS country_name",
      "departments.name AS department_name",
      "salary_records.id AS salary_record_id",
      "salary_records.amount AS salary_amount",
      "salary_records.currency_code AS salary_currency",
      "salary_records.pay_frequency AS salary_pay_frequency",
      "salary_records.fx_rate AS salary_fx_rate",
      "salary_records.effective_from AS salary_effective_from",
      "#{Compensation.annual_local_sql} AS annual_base_local",
      "#{Compensation.annual_reporting_sql} AS annual_base_reporting"
    ].freeze

    Page = Struct.new(:records, :page, :per_page, :total_count, :total_pages, keyword_init: true)

    # paginated: false (the export) ignores page and per_page entirely.
    def initialize(params, paginated: true)
      @query = parse_query(params)
      @country = country_param(params)
      @department = department_param(params)
      @status = parse_status(params)
      @sort = parse_sort(params)
      @direction = parse_direction(params)
      @page = paginated ? (integer_param(params, :page, positive: true) || 1) : 1
      @per_page = paginated ? (integer_param(params, :per_page, range: 1..MAX_PER_PAGE) || DEFAULT_PER_PAGE) : DEFAULT_PER_PAGE
    end

    def page
      total = filtered.count
      Page.new(records: records(offset: (@page - 1) * @per_page, limit: @per_page, total: total), page: @page,
               per_page: @per_page, total_count: total, total_pages: (total + @per_page - 1) / @per_page)
    end

    # Yields arrays of records in directory order, in LIMIT/OFFSET batches, until the result is exhausted.
    def each_batch(size: 1000)
      return enum_for(:each_batch, size: size) unless block_given?

      offset = 0
      loop do
        batch = records(offset: offset, limit: size)
        break if batch.empty?

        yield batch
        break if batch.size < size

        offset += size
      end
    end

    private

    def parse_query(params)
      value = string_param(params, :q)&.strip
      return if value.nil? || value.empty?
      invalid_parameter!(:q, "must be at most #{MAX_QUERY_LENGTH} characters") if value.length > MAX_QUERY_LENGTH

      value
    end

    def parse_status(params)
      value = string_param(params, :status)
      return if value.nil?

      Employee.employment_statuses.key?(value) ? value : invalid_parameter!(:status, "must be one of #{Employee.employment_statuses.keys.join(', ')}")
    end

    def parse_sort(params)
      value = string_param(params, :sort) || DEFAULT_SORT
      SORT_COLUMNS.key?(value) ? value : invalid_parameter!(:sort, "must be one of #{SORT_COLUMNS.keys.join(', ')}")
    end

    def parse_direction(params)
      value = string_param(params, :direction) || "asc"
      %w[asc desc].include?(value) ? value : invalid_parameter!(:direction, "must be asc or desc")
    end

    # Filters only touch employee columns, so the count needs no joins.
    def filtered
      scope = Employee.all
      scope = scope.where(country_code: @country) if @country
      scope = scope.where(department_id: @department) if @department
      scope = scope.where(employment_status: @status) if @status
      scope = scope.where(SEARCH_SQL, pattern: like_pattern(@query)) if @query
      scope
    end

    # Case-insensitive contains-match; % _ and \ in the user's text are escaped so they match literally.
    SEARCH_SQL = "employees.first_name ILIKE :pattern ESCAPE '\\' OR employees.last_name ILIKE :pattern ESCAPE '\\' " \
                 "OR (employees.first_name || ' ' || employees.last_name) ILIKE :pattern ESCAPE '\\' " \
                 "OR employees.employee_number ILIKE :pattern ESCAPE '\\'".freeze

    def like_pattern(text)
      "%#{text.gsub(/[\\%_]/) { |char| "\\#{char}" }}%"
    end

    def records(offset:, limit:, total: nil)
      return [] if total && offset >= total

      filtered.joins(:country, :department).joins(CURRENT_SALARY_JOIN)
              .select(*SELECTED_COLUMNS).order(order_clause).limit(limit).offset(offset).to_a
    end

    # Every sort ends with the employee id so pages never repeat or skip rows. Employees without a
    # current salary (not expected) sort last when ordering by salary.
    def order_clause
      direction = @direction.upcase
      nulls = @sort == "annual_base_reporting" ? " NULLS LAST" : ""
      parts = SORT_COLUMNS.fetch(@sort).map { |column| "#{column} #{direction}#{nulls}" }
      Arel.sql((parts + [ "employees.id ASC" ]).join(", "))
    end
  end
end
