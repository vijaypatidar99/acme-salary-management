require "rails_helper"

RSpec.describe SalaryRevisions::Create do
  # A clock the spec controls; counts reads so "one read" can be asserted.
  class FixedClock
    attr_reader :reads

    def initialize(time)
      @time = time
      @reads = 0
    end

    def now
      @reads += 1
      raise "clock read more than once" if @reads > 1

      @time
    end
  end

  let(:now) { Time.utc(2026, 11, 17, 9, 30, 0, 123_456) }
  let(:clock) { FixedClock.new(now) }
  let!(:inr) { create_currencies_and_rates && Currency.find("INR") }
  let!(:employee) { create(:employee) }
  let!(:current) do
    create(:salary_record, employee: employee, currency: inr, amount: "250000.00", pay_frequency: "monthly",
                           fx_rate: "0.012", effective_from: Time.utc(2025, 4, 1), reason: "Annual review")
  end
  let(:params) do
    { amount: "270000.00", currency: "INR", pay_frequency: "monthly", reason: "Promotion",
      expected_current_salary_record_id: current.id }
  end

  def revise(employee_id: employee.id, clock: self.clock, **overrides)
    described_class.call(employee_id: employee_id, params: params.merge(overrides), clock: clock)
  end

  def expect_domain_error(code, &block)
    expect(&block).to raise_error(DomainError) { |e| expect(e.code).to eq(code) }
  end

  def expect_nothing_written
    expect(SalaryRecord.where(employee_id: employee.id).count).to eq(1)
    expect(current.reload.effective_to).to be_nil
  end

  describe "a successful revision" do
    it "closes the previous record and creates the new one with the same timestamp" do
      result = revise

      expect(result.previous_salary.reload.effective_to).to eq(now)
      expect(result.current_salary.effective_from).to eq(now)
      expect(result.previous_salary.effective_to).to eq(result.current_salary.effective_from)
      expect(result.current_salary.effective_to).to be_nil
    end

    it "stores the new salary facts and snapshots the exchange rate used" do
      salary = revise.current_salary.reload

      expect(salary).to have_attributes(amount: BigDecimal("270000.00"), currency_code: "INR", pay_frequency: "monthly",
                                        fx_rate: BigDecimal("0.012"), reason: "Promotion", employee_id: employee.id)
    end

    it "preserves the previous salary values and the whole history" do
      before = current.attributes.except("effective_to", "updated_at")

      revise

      expect(current.reload.attributes.except("effective_to", "updated_at")).to eq(before)
      expect(SalaryRecord.where(employee_id: employee.id).count).to eq(2)
      expect(SalaryRecord.where(employee_id: employee.id).current.count).to eq(1)
    end

    it "allows several revisions on the same UTC day with strictly increasing timestamps" do
      first = revise(reason: "First", clock: FixedClock.new(now))
      second = revise(amount: "280000.00", reason: "Second", expected_current_salary_record_id: first.current_salary.id, clock: FixedClock.new(now + 1.hour))

      expect(second.previous_salary.reload.effective_to).to eq(now + 1.hour)
      expect(SalaryRecord.where(employee_id: employee.id).current.count).to eq(1)
      expect(SalaryRecord.where(employee_id: employee.id).count).to eq(3)
    end

    it "keeps the closed and the new timestamps identical to the microsecond, even for a nanosecond clock" do
      nanosecond_time = Time.utc(2026, 11, 17, 9, 30, 0, Rational(123_456_789, 1000))

      result = revise(clock: FixedClock.new(nanosecond_time))

      expect(result.current_salary.reload.effective_from).to eq(nanosecond_time.floor(6))
      expect(result.previous_salary.reload.effective_to).to eq(result.current_salary.effective_from)
    end

    it "can change currency and pay frequency" do
      create_currencies_and_rates
      salary = revise(amount: "5000.00", currency: "EUR", pay_frequency: "annual").current_salary.reload

      expect(salary).to have_attributes(currency_code: "EUR", pay_frequency: "annual", fx_rate: BigDecimal("1.08"))
    end

    it "trims the reason" do
      expect(revise(reason: "  Market adjustment  ").current_salary.reason).to eq("Market adjustment")
    end

    it "accepts the maximum amount" do
      expect { revise(amount: "1000000000.00") }.not_to raise_error
    end

    it "allows revising an employee on leave" do
      employee.update!(employment_status: "on_leave")

      expect { revise }.not_to raise_error
    end
  end

  describe "transaction ordering" do
    it "reads the clock exactly once" do
      revise

      expect(clock.reads).to eq(1)
    end

    it "locks the employee row before reading the current salary record, and reads the clock after both" do
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        sql = payload[:sql]
        statements << :employee_lock if sql.include?('FROM "employees"') && sql.include?("FOR UPDATE")
        statements << :salary_read if sql.include?('FROM "salary_records"') && sql.start_with?("SELECT")
      end
      clock_probe = Class.new do
        define_method(:initialize) { |log, time| @log = log; @time = time }
        define_method(:now) { @log << :clock; @time }
      end.new(statements, now)

      revise(clock: clock_probe)
      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(statements.index(:employee_lock)).to be < statements.index(:salary_read)
      expect(statements.index(:salary_read)).to be < statements.index(:clock)
    end
  end

  describe "rejections (nothing is written)" do
    it "raises RecordNotFound for an unknown employee" do
      expect { revise(employee_id: 0) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "rejects a stale token with the current record id" do
      error = nil
      begin
        revise(expected_current_salary_record_id: current.id + 999)
      rescue DomainError => e
        error = e
      end

      expect(error.code).to eq("stale_salary_record")
      expect(error.details).to eq(current_salary_record_id: current.id)
      expect_nothing_written
    end

    it "rejects a missing token as stale (the controller rejects it earlier as invalid_request)" do
      expect_domain_error("stale_salary_record") { revise(expected_current_salary_record_id: nil) }
    end

    it "rejects a double submit: the second request carries the now-stale token" do
      revise

      expect_domain_error("stale_salary_record") { revise(clock: FixedClock.new(now + 1.minute)) }
      expect(SalaryRecord.where(employee_id: employee.id).count).to eq(2)
    end

    it "rejects a terminated employee with the employment status" do
      employee.update_columns(employment_status: "terminated", terminated_on: Date.new(2026, 1, 1))

      error = nil
      begin
        revise
      rescue DomainError => e
        error = e
      end

      expect(error.code).to eq("employee_not_eligible")
      expect(error.details).to eq(employment_status: "terminated")
      expect_nothing_written
    end

    it "checks the token before eligibility (409 beats 422)" do
      employee.update_columns(employment_status: "terminated", terminated_on: Date.new(2026, 1, 1))

      expect_domain_error("stale_salary_record") { revise(expected_current_salary_record_id: 0) }
    end

    it "checks eligibility before input validation" do
      employee.update_columns(employment_status: "terminated", terminated_on: Date.new(2026, 1, 1))

      expect_domain_error("employee_not_eligible") { revise(amount: "bad") }
    end

    describe "validation_failed" do
      {
        "a zero amount" => [ { amount: "0.00" }, :amount, "must be greater than 0" ],
        "an amount above the maximum" => [ { amount: "1000000000.01" }, :amount, "must be less than or equal to 1000000000.00" ],
        "three decimals" => [ { amount: "100.123" }, :amount, "must be a decimal number with at most two decimal places" ],
        "scientific notation" => [ { amount: "1e5" }, :amount, "must be a decimal number with at most two decimal places" ],
        "a missing amount" => [ { amount: nil }, :amount, "can't be blank" ],
        "an unknown currency" => [ { currency: "XXX" }, :currency, "is not a supported currency" ],
        "a missing currency" => [ { currency: nil }, :currency, "can't be blank" ],
        "an unknown frequency" => [ { pay_frequency: "weekly" }, :pay_frequency, "must be monthly or annual" ],
        "a blank reason" => [ { reason: "   " }, :reason, "can't be blank" ],
        "a too-long reason" => [ { reason: "a" * 256 }, :reason, "is too long (maximum is 255 characters)" ]
      }.each do |label, (overrides, field, message)|
        it "rejects #{label}" do
          error = nil
          begin
            revise(**overrides)
          rescue DomainError => e
            error = e
          end

          expect(error.code).to eq("validation_failed")
          expect(error.details[field]).to eq([ message ])
          expect_nothing_written
        end
      end

      it "reports every invalid field at once" do
        error = nil
        begin
          revise(amount: "0", currency: "XXX", reason: "")
        rescue DomainError => e
          error = e
        end

        expect(error.details.keys).to contain_exactly(:amount, :currency, :reason)
      end
    end

    it "rejects a revision that changes nothing (DR-10 working default)" do
      expect_domain_error("no_change") { revise(amount: "250000.00") }
      expect_nothing_written
    end

    it "treats a different currency or frequency as a change even when the amount is the same" do
      expect { revise(amount: "250000.00", pay_frequency: "annual") }.not_to raise_error
    end

    it "rejects a currency without an exchange rate and never defaults it to 1" do
      Currency.create!(code: "JPY", name: "Yen")

      error = nil
      begin
        revise(currency: "JPY")
      rescue DomainError => e
        error = e
      end

      expect(error.code).to eq("missing_exchange_rate")
      expect(error.details).to eq(currency: "JPY")
      expect_nothing_written
    end

    it "uses the UTC date of the single timestamp to select the rate" do
      create(:exchange_rate, from_currency: "INR", rate: BigDecimal("0.0130"), effective_on: Date.new(2026, 11, 18))
      # 2026-11-18 02:00 at +05:30 is 2026-11-17 20:30 UTC, so the 18th's rate must not apply.
      local_time = Time.new(2026, 11, 18, 2, 0, 0, "+05:30")

      salary = revise(clock: FixedClock.new(local_time)).current_salary

      expect(salary.fx_rate).to eq(BigDecimal("0.012"))
      expect(salary.effective_from).to eq(Time.utc(2026, 11, 17, 20, 30))
    end

    it "does not use a rate that only becomes effective after the revision date" do
      ExchangeRate.where(from_currency: "INR").update_all(effective_on: Date.new(2026, 11, 18))

      expect_domain_error("missing_exchange_rate") { revise }
      expect_nothing_written
    end

    it "rejects a timestamp that is not strictly later than the current record" do
      expect_domain_error("revision_conflict") { revise(clock: FixedClock.new(current.effective_from)) }
      expect_domain_error("revision_conflict") { revise(clock: FixedClock.new(current.effective_from - 1)) }
      expect_nothing_written
    end
  end

  describe "rollback" do
    def fail_on_new_record(error)
      allow_any_instance_of(SalaryRecord).to receive(:save!).and_wrap_original do |original, *args|
        raise error if original.receiver.new_record?

        original.call(*args)
      end
    end

    it "undoes the close when the insert fails" do
      fail_on_new_record(ActiveRecord::StatementInvalid.new("insert failed"))

      expect { revise }.to raise_error(ActiveRecord::StatementInvalid)

      expect_nothing_written
    end

    it "maps an exclusion violation from the database to revision_conflict and rolls back" do
      fail_on_new_record(ActiveRecord::ExclusionViolation.new("overlap"))

      expect_domain_error("revision_conflict") { revise }
      expect_nothing_written
    end
  end

  describe "invariant guard" do
    it "fails loudly if an employee has no current record instead of inventing one" do
      current.update_columns(effective_to: Time.utc(2025, 6, 1))

      expect { revise }.to raise_error(RuntimeError, /no current salary record/)
    end
  end
end
