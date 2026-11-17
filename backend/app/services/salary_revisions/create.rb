module SalaryRevisions
  # Records a new base salary effective immediately (docs/domain-decisions.md §7). One transaction:
  #
  #   lock employee → read current record (after the lock) → token check → eligibility →
  #   validate input and no-op → read the clock ONCE → FX rate for that instant's UTC date →
  #   reject if not later than the current record → close previous → insert new.
  #
  # Nothing is written until every check has passed, and the previous record is only ever closed
  # (effective_to set); its salary facts are never edited. Raises DomainError (rolling back) on any
  # business-rule failure and ActiveRecord::RecordNotFound for an unknown employee.
  class Create
    Result = Struct.new(:employee, :current_salary, :previous_salary, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    # params: amount (String), currency, pay_frequency, reason, expected_current_salary_record_id (Integer).
    # clock: anything responding to #now; injectable so specs can fix and count clock reads.
    def initialize(employee_id:, params:, clock: Time)
      @employee_id = employee_id
      @params = params
      @clock = clock
    end

    def call
      Employee.transaction do
        employee = Employee.lock.find(@employee_id)
        current = current_salary_record_of(employee)

        check_token!(current)
        check_eligibility!(employee)
        input = validated_input
        check_changed!(current, input)

        effective_at = @clock.now.utc.floor(6)
        rate = exchange_rate_for!(input.fetch(:currency_code), effective_at)
        raise_conflict! unless effective_at > current.effective_from

        close_and_insert(employee, current, input, rate, effective_at)
      end
    rescue ActiveRecord::ExclusionViolation, ActiveRecord::RecordNotUnique
      # The database is the final guarantee against overlap or a second open record.
      raise_conflict!
    end

    private

    # Read only after the row lock is held, never before.
    def current_salary_record_of(employee)
      employee.salary_records.current.first or
        raise "Employee #{employee.id} has no current salary record (every employee must have exactly one)"
    end

    def check_token!(current)
      return if @params[:expected_current_salary_record_id] == current.id

      raise DomainError.new("stale_salary_record", "The salary record changed since it was loaded",
                            details: { current_salary_record_id: current.id })
    end

    def check_eligibility!(employee)
      return if employee.can_revise_salary?

      raise DomainError.new("employee_not_eligible", "Salary revisions are not allowed for this employment status",
                            details: { employment_status: employee.employment_status })
    end

    def validated_input
      errors = {}
      errors[:amount] = SalaryAmount.errors_for(@params[:amount])
      errors[:currency] = currency_errors
      errors[:pay_frequency] = pay_frequency_errors
      errors[:reason] = reason_errors
      errors.select! { |_field, messages| messages.any? }
      raise validation_failed(errors) if errors.any?

      { amount: SalaryAmount.parse(@params[:amount]), currency_code: @params[:currency],
        pay_frequency: @params[:pay_frequency], reason: reason }
    end

    def currency_errors
      return [ "can't be blank" ] if @params[:currency].blank?
      return [ "is not a supported currency" ] unless @params[:currency].match?(/\A[A-Z]{3}\z/)

      Currency.exists?(code: @params[:currency]) ? [] : [ "is not a supported currency" ]
    end

    def pay_frequency_errors
      return [ "can't be blank" ] if @params[:pay_frequency].blank?

      SalaryRecord::PAY_FREQUENCIES.include?(@params[:pay_frequency]) ? [] : [ "must be monthly or annual" ]
    end

    def reason
      @params[:reason].to_s.strip
    end

    def reason_errors
      return [ "can't be blank" ] if reason.empty?
      return [ "must not contain NUL characters" ] if reason.include?("\0")

      reason.length > 255 ? [ "is too long (maximum is 255 characters)" ] : []
    end

    def validation_failed(errors)
      field, messages = errors.first
      DomainError.new("validation_failed", "#{field.to_s.humanize} #{messages.first}", details: errors)
    end

    # DR-10 (working default, pending approval): amount, currency and frequency all unchanged is not a revision.
    def check_changed!(current, input)
      return unless input[:amount] == current.amount && input[:currency_code] == current.currency_code &&
                    input[:pay_frequency] == current.pay_frequency

      raise DomainError.new("no_change", "Amount, currency and pay frequency match the current salary")
    end

    # The UTC date of the single effective timestamp selects the rate. A missing rate is never defaulted to 1.
    def exchange_rate_for!(currency_code, effective_at)
      ExchangeRate.lookup(currency_code, on: effective_at) or
        raise DomainError.new("missing_exchange_rate", "No exchange rate to USD for #{currency_code} on #{effective_at.to_date}",
                              details: { currency: currency_code })
    end

    def raise_conflict!
      raise DomainError.new("revision_conflict", "The salary revision conflicts with the existing salary history")
    end

    # Close first, then insert: the exclusion constraint is checked per statement, so closing first
    # leaves no overlap at insert time. Both writes use the same timestamp.
    def close_and_insert(employee, current, input, rate, effective_at)
      current.update!(effective_to: effective_at)
      created = employee.salary_records.create!(
        amount: input[:amount], currency_code: input[:currency_code], pay_frequency: input[:pay_frequency],
        fx_rate: rate.rate, effective_from: effective_at, effective_to: nil, reason: input[:reason]
      )
      Result.new(employee: employee, current_salary: created, previous_salary: current)
    end
  end
end
