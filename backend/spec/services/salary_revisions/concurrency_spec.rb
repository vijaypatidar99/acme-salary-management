require "rails_helper"

# Two real connections: transactional examples cannot show lock behaviour, so this group commits its
# data and cleans up afterwards. Ordering is forced with a barrier and by polling PostgreSQL for a
# backend that is waiting on a lock, not with sleeps.
RSpec.describe SalaryRevisions::Create, "concurrency" do
  self.use_transactional_tests = false

  class HoldingClock
    def initialize(holding, release, time)
      @holding = holding
      @release = release
      @time = time
    end

    # Called after the row lock is taken: report it, then wait until the spec lets us go on.
    def now
      @holding << :holding_lock
      @release.pop
      @time
    end
  end

  def clean_database
    [ SalaryRecord, Employee, ExchangeRate, Currency, Department, Country ].each(&:delete_all)
  end

  def wait_until(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    sleep 0.01 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    raise "timed out waiting for the second request to block on the row lock" unless yield
  end

  def a_backend_is_waiting_on_a_lock?
    ActiveRecord::Base.connection.select_value(
      "SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock' AND datname = current_database()"
    ).positive?
  end

  before { clean_database }
  after { clean_database }

  it "serialises two revisions of the same employee: the first wins and the second is stale" do
    create_currencies_and_rates
    employee = create(:employee)
    current = create(:salary_record, employee: employee, currency: Currency.find("USD"), amount: "90000.00",
                                     effective_from: Time.utc(2025, 1, 1))
    params = { amount: "95000.00", currency: "USD", pay_frequency: "annual", reason: "Race",
               expected_current_salary_record_id: current.id }
    holding = Queue.new
    release = Queue.new

    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        described_class.call(employee_id: employee.id, params: params, clock: HoldingClock.new(holding, release, Time.utc(2026, 11, 17, 9, 0)))
      end
    end
    raise "first revision did not acquire its lock" unless holding.pop(timeout: 5)
    second = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        described_class.call(employee_id: employee.id, params: params.merge(reason: "Second"), clock: Time)
      rescue DomainError => e
        e
      end
    end
    wait_until { a_backend_is_waiting_on_a_lock? } # the second request is blocked on the same lock
    release << :go

    raise "first revision did not finish" unless first.join(5)
    raise "second revision did not finish" unless second.join(5)
    winner = first.value
    loser = second.value

    expect(winner.current_salary.reason).to eq("Race")
    expect(loser).to be_a(DomainError)
    expect(loser.code).to eq("stale_salary_record")
    expect(loser.details).to eq(current_salary_record_id: current.id + 1)

    history = SalaryRecord.where(employee_id: employee.id).order(:effective_from)
    expect(history.count).to eq(2)
    expect(history.current.count).to eq(1)
    expect(history.first.effective_to).to eq(history.last.effective_from)
  ensure
    release << :go if release
    [ first, second ].compact.each do |thread|
      thread.kill unless thread.join(1)
      thread.join
    end
  end
end
