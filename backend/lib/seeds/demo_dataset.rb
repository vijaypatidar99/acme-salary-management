require "digest"

module Seeds
  # The deterministic synthetic dataset (docs/domain-decisions.md §11): exactly 10,000 fictional
  # employees across several countries, currencies, departments, levels and statuses, each with a
  # current salary record and, for a fixed share, 1–3 closed historical records.
  #
  # Deterministic: one fixed RNG seed and one fixed anchor date (never Date.today), so two runs on an
  # empty database produce identical rows. All values are fabricated and the exchange rates are
  # illustrative planning rates, not market data. The exact proportions below are DR-17 working
  # defaults (approval pending); they make no claim of realism.
  #
  # Money is BigDecimal throughout. fx_rate for every record comes from ExchangeRate.lookup, the same
  # rule the revision service uses; annual values are never stored (they derive from Compensation).
  class DemoDataset
    class Error < StandardError; end

    SEED = 20_261_117
    ANCHOR_DATE = Date.new(2026, 11, 1) # must be on or before the deployment date
    ANCHOR_TIME = Time.utc(2026, 11, 1)
    HIRE_EARLIEST = Date.new(2012, 1, 1)
    RATE_FLOOR = Date.new(2010, 1, 1) # earlier than any seeded salary
    EMPLOYEE_COUNT = 10_000
    NON_HOME_CURRENCY_PERCENT = 3
    BATCH_SIZE = 1000

    CURRENCIES = { "USD" => "US Dollar", "EUR" => "Euro", "GBP" => "Pound Sterling", "INR" => "Indian Rupee" }.freeze
    RATES_TO_USD = { "USD" => "1.00000000", "EUR" => "1.08000000", "GBP" => "1.27000000", "INR" => "0.01200000" }.freeze

    # code → [name, home currency, usual pay frequency, weight, pay level vs the USD scale]
    COUNTRIES = {
      "IN" => [ "India", "INR", "monthly", 3200, "0.35" ],
      "US" => [ "United States", "USD", "annual", 2800, "1.00" ],
      "GB" => [ "United Kingdom", "GBP", "annual", 1500, "0.85" ],
      "DE" => [ "Germany", "EUR", "monthly", 1200, "0.85" ],
      "FR" => [ "France", "EUR", "monthly", 1292, "0.80" ],
      "IE" => [ "Ireland", "EUR", "monthly", 8, "0.90" ] # tiny on purpose: a low-sample country
    }.freeze

    # name → [role, weight, pay factor]
    DEPARTMENTS = {
      "Engineering" => [ "Engineer", 3000, "1.20" ], "Product" => [ "Product Manager", 900, "1.15" ],
      "Design" => [ "Designer", 600, "1.00" ], "Sales" => [ "Sales Executive", 2000, "1.05" ],
      "Marketing" => [ "Marketing Specialist", 900, "0.95" ], "Finance" => [ "Financial Analyst", 700, "1.05" ],
      "Human Resources" => [ "HR Partner", 500, "0.90" ], "Operations" => [ "Operations Analyst", 1393, "0.90" ],
      "Legal" => [ "Legal Counsel", 7, "1.25" ] # tiny on purpose: a low-sample department
    }.freeze

    STATUS_WEIGHTS = { "active" => 9200, "on_leave" => 300, "terminated" => 500 }.freeze
    LEVEL_WEIGHTS = { 1 => 1200, 2 => 2000, 3 => 2600, 4 => 2000, 5 => 1300, 6 => 700, 7 => 200 }.freeze
    LEVEL_LABELS = %w[Junior Associate Mid-level Senior Lead Principal Head].freeze
    LEVEL_BASE_USD = %w[38000 52000 70000 92000 120000 160000 220000].freeze
    HISTORY_WEIGHTS = { 0 => 60, 1 => 25, 2 => 10, 3 => 5 }.freeze # share of employees by number of closed records
    HISTORY_POOL = HISTORY_WEIGHTS.flat_map { |count, weight| [ count ] * weight }.freeze
    RAISE_RATIO = BigDecimal("1.07")
    REVISION_REASONS = [ "Annual review", "Promotion", "Market adjustment", "Role change" ].freeze
    MIN_DAYS_PER_RECORD = 30

    TABLES = %w[salary_records employees exchange_rates departments countries currencies].freeze

    def self.call(**)
      new(**).call
    end

    # reset: wipe the six tables first (needed to re-seed a database that already has data).
    def initialize(employee_count: EMPLOYEE_COUNT, reset: false)
      @employee_count = employee_count
      @reset = reset
    end

    def call
      guard_production!
      return existing_dataset_result if Employee.exists? && !@reset

      ApplicationRecord.transaction do
        truncate! if @reset
        insert_reference_data
        insert_employees_and_salaries
        reset_sequences
        verify! # A failed verification must also roll back a reset and restore the previous dataset.
      end
    end

    # Raises Error describing every violated invariant; returns a summary hash otherwise.
    def verify!
      problems = invariant_problems
      raise Error, "Seed verification failed:\n- #{problems.join("\n- ")}" if problems.any?

      summary
    end

    def fingerprint
      digest = Digest::SHA256.new
      Employee.order(:id).pluck(:id, :employee_number, :first_name, :last_name, :job_title, :job_level, :department_id,
                                :country_code, :employment_status, :hired_on, :terminated_on).each { |row| digest << row.join("|") << "\n" }
      SalaryRecord.order(:id).pluck(:id, :employee_id, :amount, :currency_code, :pay_frequency, :fx_rate,
                                    :effective_from, :effective_to, :reason).each { |row| digest << row.map { |v| v.is_a?(Time) ? v.utc.iso8601(6) : v }.join("|") << "\n" }
      digest.hexdigest
    end

    private

    def rng
      @rng ||= Random.new(SEED)
    end

    def guard_production!
      return unless Rails.env.production? && ENV["ALLOW_PRODUCTION_SEED"] != "1"

      raise Error, "Refusing to seed demo data in production. Set ALLOW_PRODUCTION_SEED=1 to override deliberately."
    end

    def existing_dataset_result
      summary.merge(already_seeded: true).tap { verify! }
    rescue Error => e
      raise Error, "The database already contains data that is not this dataset (#{e.message.lines.first.strip}). " \
                   "Re-run with RESET=1 to replace everything (this deletes employees, salary records and rates)."
    end

    def truncate!
      ApplicationRecord.connection.execute("TRUNCATE #{TABLES.join(', ')} RESTART IDENTITY CASCADE")
    end

    # ---- generation ---------------------------------------------------------------------------

    def insert_reference_data
      Currency.insert_all!(CURRENCIES.map { |code, name| { code: code, name: name } })
      Country.insert_all!(COUNTRIES.map { |code, (name)| { code: code, name: name } })
      Department.insert_all!(department_names.each_with_index.map { |name, index| { id: index + 1, name: name } })
      ExchangeRate.insert_all!(RATES_TO_USD.each_with_index.map do |(code, rate), index|
        { id: index + 1, from_currency: code, to_currency: Compensation::REPORTING_CURRENCY, rate: rate, effective_on: RATE_FLOOR, created_at: ANCHOR_TIME }
      end)
    end

    def department_names
      DEPARTMENTS.keys
    end

    def insert_employees_and_salaries
      countries = allocate(COUNTRIES.transform_values { |v| v[3] })
      departments = allocate(DEPARTMENTS.transform_values { |v| v[1] })
      statuses = allocate(STATUS_WEIGHTS)
      levels = allocate(LEVEL_WEIGHTS)
      salary_id = 0

      (0...@employee_count).each_slice(BATCH_SIZE) do |indexes|
        employees = []
        salaries = []
        indexes.each do |index|
          employee = build_employee(index, countries[index], departments[index], statuses[index], levels[index])
          employees << employee.fetch(:row)
          build_salary_rows(employee).each { |row| salaries << row.merge(id: (salary_id += 1)) }
        end
        Employee.insert_all!(employees)
        SalaryRecord.insert_all!(salaries)
      end
    end

    # Largest-remainder apportionment of `count` slots over the weights, shuffled with the seeded RNG.
    # With the default count the weights sum to exactly 10,000, so every group gets exactly its weight.
    def allocate(weights)
      total = weights.values.sum
      exact = weights.transform_values { |w| Rational(w * @employee_count, total) }
      counts = exact.transform_values(&:floor)
      leftover = @employee_count - counts.values.sum
      exact.sort_by { |key, value| [ -(value - value.floor), key.to_s ] }.first(leftover).each { |key, _| counts[key] += 1 }
      counts.flat_map { |key, count| [ key ] * count }.shuffle(random: rng)
    end

    def build_employee(index, country_code, department, status, level)
      hired_on = HIRE_EARLIEST + rng.rand((ANCHOR_DATE - 60 - HIRE_EARLIEST).to_i)
      terminated_on = status == "terminated" ? hired_on + rng.rand(MIN_DAYS_PER_RECORD..(ANCHOR_DATE - hired_on).to_i) : nil
      {
        country_code: country_code, department: department, level: level, hired_on: hired_on, end_date: terminated_on || ANCHOR_DATE,
        row: {
          id: index + 1, employee_number: format("ACME-%05d", index + 1),
          first_name: Names::FIRST.fetch(rng.rand(Names::FIRST.size)), last_name: Names::LAST.fetch(rng.rand(Names::LAST.size)),
          job_title: "#{LEVEL_LABELS.fetch(level - 1)} #{DEPARTMENTS.fetch(department).first}", job_level: level,
          department_id: department_names.index(department) + 1, country_code: country_code, employment_status: status,
          hired_on: hired_on, terminated_on: terminated_on, created_at: ANCHOR_TIME, updated_at: ANCHOR_TIME
        }
      }
    end

    def build_salary_rows(employee)
      pay = pay_terms(employee)
      history = history_count(employee)
      starts = record_starts(employee, history)
      starts.each_with_index.map do |from, position|
        { employee_id: employee[:row][:id], amount: amount_for(pay, history - position), currency_code: pay[:currency],
          pay_frequency: pay[:frequency], fx_rate: ExchangeRate.lookup(pay[:currency], on: from).rate,
          effective_from: from, effective_to: starts[position + 1], reason: position.zero? ? "Initial salary" : REVISION_REASONS.fetch(rng.rand(REVISION_REASONS.size)),
          created_at: ANCHOR_TIME, updated_at: ANCHOR_TIME }
      end
    end

    # Home currency (a small share is paid in another currency) and the country's usual frequency
    # (a share uses the other one); the current annual USD value, then the pay-period amount in that currency.
    def pay_terms(employee)
      _name, home, usual_frequency, _weight, country_factor = COUNTRIES.fetch(employee[:country_code])
      currency = rng.rand(100) < NON_HOME_CURRENCY_PERCENT ? other_currency(home) : home
      frequency = rng.rand(100) < 15 ? other_frequency(usual_frequency) : usual_frequency
      usd_annual = BigDecimal(LEVEL_BASE_USD.fetch(employee[:level] - 1)) * BigDecimal(DEPARTMENTS.fetch(employee[:department]).last) *
                   BigDecimal(country_factor) * rng.rand(90..110) / 100
      periods = Compensation::PERIODS_PER_YEAR.fetch(frequency)
      { currency: currency, frequency: frequency, current: (usd_annual / periods / BigDecimal(RATES_TO_USD.fetch(currency))).round(2, :half_up) }
    end

    def other_currency(home)
      others = CURRENCIES.keys - [ home ]
      others.fetch(rng.rand(others.size))
    end

    def other_frequency(frequency)
      frequency == "monthly" ? "annual" : "monthly"
    end

    def amount_for(pay, records_before_current)
      (pay[:current] / (RAISE_RATIO**records_before_current)).round(2, :half_up)
    end

    # How many closed records this employee has: a weighted pick, limited so every record spans at
    # least MIN_DAYS_PER_RECORD days between hiring and the end date.
    def history_count(employee)
      desired = HISTORY_POOL.fetch(rng.rand(HISTORY_POOL.size))
      room = (employee[:end_date] - employee[:hired_on]).to_i / MIN_DAYS_PER_RECORD - 1
      desired.clamp(0, [ room, 0 ].max)
    end

    # Start timestamps of the history + current records: hired_on, then evenly spaced whole days, all
    # at 09:00 UTC, all before the end date. Each record ends exactly where the next one starts.
    def record_starts(employee, history)
      span = (employee[:end_date] - employee[:hired_on]).to_i
      (0..history).map do |position|
        day = employee[:hired_on] + (span * position / (history + 1))
        Time.utc(day.year, day.month, day.day, 9)
      end
    end

    def reset_sequences
      %w[departments employees salary_records exchange_rates].each { |table| ApplicationRecord.connection.reset_pk_sequence!(table) }
    end

    # ---- verification -------------------------------------------------------------------------

    def invariant_problems
      conn = ApplicationRecord.connection
      problems = []
      problems << "expected #{@employee_count} employees, found #{Employee.count}" unless Employee.count == @employee_count
      count = ->(sql) { conn.select_value(sql).to_i }

      problems << "#{count.call(NO_OPEN_RECORD_SQL)} employees without exactly one open salary record" unless count.call(NO_OPEN_RECORD_SQL).zero?
      problems << "#{count.call(OVERLAP_SQL)} overlapping salary intervals" unless count.call(OVERLAP_SQL).zero?
      problems << "#{count.call(GAP_SQL)} gaps between consecutive salary records" unless count.call(GAP_SQL).zero?
      problems << "#{count.call(BEFORE_HIRE_SQL)} salary records starting before the hire date" unless count.call(BEFORE_HIRE_SQL).zero?
      problems << "#{count.call(AFTER_TERMINATION_SQL)} salary records starting on or after the termination date" unless count.call(AFTER_TERMINATION_SQL).zero?
      problems << "#{count.call(FX_MISMATCH_SQL)} salary records whose fx_rate differs from the rate lookup" unless count.call(FX_MISMATCH_SQL).zero?
      problems << "#{count.call(BLANK_REASON_SQL)} salary records with a blank reason" unless count.call(BLANK_REASON_SQL).zero?
      problems << "terminated_on rule violated" unless count.call(TERMINATED_RULE_SQL).zero?
      problems
    end

    def summary
      {
        employees: Employee.count, salary_records: SalaryRecord.count, historical_records: SalaryRecord.where.not(effective_to: nil).count,
        countries: Country.count, departments: Department.count, currencies: Currency.count,
        status_counts: Employee.group(:employment_status).count, fingerprint: fingerprint
      }
    end

    NO_OPEN_RECORD_SQL = <<~SQL.squish.freeze
      SELECT count(*) FROM employees e
      WHERE (SELECT count(*) FROM salary_records s WHERE s.employee_id = e.id AND s.effective_to IS NULL) <> 1
    SQL
    OVERLAP_SQL = <<~SQL.squish.freeze
      SELECT count(*) FROM salary_records a JOIN salary_records b ON a.employee_id = b.employee_id AND a.id < b.id
      AND tstzrange(a.effective_from, a.effective_to, '[)') && tstzrange(b.effective_from, b.effective_to, '[)')
    SQL
    GAP_SQL = <<~SQL.squish.freeze
      SELECT count(*) FROM (SELECT effective_from, LAG(effective_to) OVER (PARTITION BY employee_id ORDER BY effective_from) AS previous_to
      FROM salary_records) t WHERE previous_to IS NOT NULL AND previous_to <> effective_from
    SQL
    BEFORE_HIRE_SQL = "SELECT count(*) FROM salary_records s JOIN employees e ON e.id = s.employee_id WHERE s.effective_from < e.hired_on".freeze
    AFTER_TERMINATION_SQL = <<~SQL.squish.freeze
      SELECT count(*) FROM salary_records s JOIN employees e ON e.id = s.employee_id
      WHERE e.terminated_on IS NOT NULL AND s.effective_from >= e.terminated_on
    SQL
    FX_MISMATCH_SQL = <<~SQL.squish.freeze
      SELECT count(*) FROM salary_records s WHERE s.fx_rate IS DISTINCT FROM (
        SELECT r.rate FROM exchange_rates r WHERE r.from_currency = s.currency_code AND r.to_currency = 'USD'
        AND r.effective_on <= s.effective_from::date ORDER BY r.effective_on DESC LIMIT 1)
    SQL
    BLANK_REASON_SQL = "SELECT count(*) FROM salary_records WHERE btrim(reason) = ''".freeze
    TERMINATED_RULE_SQL = <<~SQL.squish.freeze
      SELECT count(*) FROM employees WHERE (employment_status = 'terminated') <> (terminated_on IS NOT NULL)
    SQL
  end
end
