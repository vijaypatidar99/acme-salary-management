require "rails_helper"

RSpec.describe "POST /api/v1/employees/:id/salary_revisions", type: :request do
  let(:write_key) { "correct-horse-battery-staple" }
  let!(:employees) { create_demo_population }
  let(:employee) { employees.first } # ACME-00001, INR 250,000 monthly
  let(:current) { employee.salary_records.current.first }
  let(:path) { "/api/v1/employees/#{employee.id}/salary_revisions" }
  let(:revision) do
    { amount: "270000.00", currency: "INR", pay_frequency: "monthly", reason: "Annual review",
      expected_current_salary_record_id: current.id }
  end

  around do |example|
    original = ENV["DEMO_WRITE_KEY"]
    ENV["DEMO_WRITE_KEY"] = write_key
    example.run
  ensure
    original.nil? ? ENV.delete("DEMO_WRITE_KEY") : ENV["DEMO_WRITE_KEY"] = original
  end

  def post_revision(body = { salary_revision: revision }, key: write_key, headers: {})
    auth = key ? { "Authorization" => "Bearer #{key}" } : {}
    raw = body.is_a?(String) ? body : body.to_json
    post path, params: raw, headers: { "Content-Type" => "application/json" }.merge(auth).merge(headers)
  end

  def history_size
    SalaryRecord.where(employee_id: employee.id).count
  end

  def error_code
    json.dig("error", "code")
  end

  describe "write protection (DR-02 recommended default)" do
    it "returns 403 writes_disabled for every write when no key is configured, with or without a header" do
      ENV.delete("DEMO_WRITE_KEY")

      post_revision(key: write_key)
      expect(response).to have_http_status(:forbidden)
      expect(error_code).to eq("writes_disabled")

      post_revision(key: nil)
      expect(response).to have_http_status(:forbidden)

      post_revision("{ not json", key: nil)
      expect(response).to have_http_status(:forbidden) # 403 beats 400
      expect(history_size).to eq(1)
    end

    it "treats an empty configured key as unconfigured (fail closed)" do
      ENV["DEMO_WRITE_KEY"] = ""

      post_revision(key: "")

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 when the key is missing or wrong, and writes nothing" do
      [ nil, "wrong", "correct-horse-battery-stapl", "#{write_key}x", "" ].each do |key|
        post_revision(key: key)

        expect(response).to have_http_status(:unauthorized), "key #{key.inspect}"
        expect(error_code).to eq("unauthorized")
      end
      expect(response.headers["WWW-Authenticate"]).to eq("Bearer")
      expect(history_size).to eq(1)
    end

    it "rejects another authorization scheme" do
      post_revision(key: nil, headers: { "Authorization" => "Basic #{Base64.strict_encode64("admin:#{write_key}")}" })

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects the key when it is sent anywhere but the Authorization header" do
      post "#{path}?key=#{write_key}", params: { salary_revision: revision }.to_json, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts the correct key" do
      post_revision

      expect(response).to have_http_status(:created)
    end

    it "uses a constant-time comparison of equal-length digests" do
      allow(ActiveSupport::SecurityUtils).to receive(:fixed_length_secure_compare).and_call_original

      post_revision(key: "short")

      expect(ActiveSupport::SecurityUtils).to have_received(:fixed_length_secure_compare) do |a, b|
        expect([ a.bytesize, b.bytesize ]).to eq([ 32, 32 ])
      end
    end

    it "protects only the write endpoint: reads need no key" do
      get "/api/v1/employees"

      expect(response).to have_http_status(:ok)
    end

    it "never puts the key in a response body or in the log" do
      log = StringIO.new
      original_logger = ActionController::Base.logger
      ActionController::Base.logger = ActiveSupport::Logger.new(log)

      post_revision
      post_revision(key: "wrong-key-value")
      post_revision({ salary_revision: revision.merge(amount: "0") }, key: write_key)
      ActionController::Base.logger = original_logger

      expect(response.body).not_to include(write_key)
      expect(log.string).to include("Processing by Api::V1::SalaryRevisionsController#create")
      expect(log.string).not_to include(write_key)
      expect(log.string).not_to include("wrong-key-value")
      expect(log.string.downcase).not_to include("authorization")
    end
  end

  describe "a successful revision" do
    it "returns 201 with the new and the previous record, money as strings" do
      post_revision

      expect(response).to have_http_status(:created)
      data = json["data"]
      expect(data["employee_id"]).to eq(employee.id)
      expect(data["reporting_currency"]).to eq("USD")
      expect(data["current_salary"]).to include(
        "amount" => "270000.00", "currency" => "INR", "pay_frequency" => "monthly", "fx_rate" => "0.01200000",
        "annual_base_local" => "3240000.00", "annual_base_reporting" => "38880.00",
        "effective_to" => nil, "reason" => "Annual review", "is_current" => true
      )
      expect(data["previous_salary"]).to include("id" => current.id, "amount" => "250000.00", "is_current" => false)
      expect(data["previous_salary"]["effective_to"]).to eq(data["current_salary"]["effective_from"])
      expect(data["current_salary"]["effective_from"]).to match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}Z\z/)
    end

    it "keeps the history and exposes it through the employee endpoint" do
      post_revision

      get "/api/v1/employees/#{employee.id}"
      history = json["data"]["salary_history"]
      expect(history.map { |r| r["amount"] }).to eq([ "270000.00", "250000.00" ])
      expect(history.map { |r| r["is_current"] }).to eq([ true, false ])
    end

    it "lets an employee on leave be revised but is reflected in analytics only while active (DR-03)" do
      on_leave = employees.find { |e| e.employment_status == "on_leave" }

      post "/api/v1/employees/#{on_leave.id}/salary_revisions",
           params: { salary_revision: revision.merge(amount: "200000.00", expected_current_salary_record_id: on_leave.salary_records.current.first.id) }.to_json,
           headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{write_key}" }

      expect(response).to have_http_status(:created)
      get "/api/v1/analytics/summary"
      expect(json["data"]["organization"]["active_headcount"]).to eq(4)
    end
  end

  describe "400 invalid_request (structural)" do
    it "rejects malformed JSON" do
      post_revision("{ not json")

      expect(response).to have_http_status(:bad_request)
      expect(error_code).to eq("invalid_request")
    end

    it "rejects a missing or non-object salary_revision" do
      [ {}, { salary_revision: nil }, { salary_revision: "x" }, { salary_revision: [ 1 ] }, { other: 1 } ].each do |body|
        post_revision(body)

        expect(response).to have_http_status(:bad_request), body.inspect
        expect(error_code).to eq("invalid_request")
      end
    end

    it "rejects a JSON number for amount (it must be a decimal string)" do
      post_revision({ salary_revision: revision.merge(amount: 270_000) })

      expect(response).to have_http_status(:bad_request)
      expect(error_code).to eq("invalid_request")
      expect(history_size).to eq(1)
    end

    it "rejects other wrong JSON types" do
      [ { currency: 1 }, { pay_frequency: true }, { reason: 5 } ].each do |override|
        post_revision({ salary_revision: revision.merge(override) })

        expect(response).to have_http_status(:bad_request), override.inspect
      end
    end

    it "rejects a missing, null, string or fractional token" do
      [ nil, "9001", 9001.5, true ].each do |token|
        post_revision({ salary_revision: revision.merge(expected_current_salary_record_id: token) })

        expect(response).to have_http_status(:bad_request), token.inspect
      end
      post_revision({ salary_revision: revision.except(:expected_current_salary_record_id) })
      expect(response).to have_http_status(:bad_request)
    end

    it "checks structure (400) before the employee exists (404)" do
      post "/api/v1/employees/0/salary_revisions", params: "{ bad", headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{write_key}" }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "404, 409 and 422" do
    it "returns 404 not_found for an unknown employee" do
      post "/api/v1/employees/0/salary_revisions", params: { salary_revision: revision }.to_json,
                                                    headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{write_key}" }

      expect(response).to have_http_status(:not_found)
      expect(error_code).to eq("not_found")
    end

    it "returns 409 stale_salary_record with the current record id, and writes nothing" do
      post_revision({ salary_revision: revision.merge(expected_current_salary_record_id: current.id + 100) })

      expect(response).to have_http_status(:conflict)
      expect(error_code).to eq("stale_salary_record")
      expect(json["error"]["details"]).to eq("current_salary_record_id" => current.id)
      expect(history_size).to eq(1)
    end

    it "makes a double submit harmless: the second identical request is stale" do
      post_revision
      expect(response).to have_http_status(:created)

      post_revision
      expect(response).to have_http_status(:conflict)
      expect(error_code).to eq("stale_salary_record")
      expect(history_size).to eq(2)
    end

    it "returns 409 revision_conflict when the timestamp is not later than the current record" do
      SalaryRecord.where(id: current.id).update_all(effective_from: 1.day.from_now) # bypasses the model's read-only guard on purpose

      post_revision

      expect(response).to have_http_status(:conflict)
      expect(error_code).to eq("revision_conflict")
      expect(history_size).to eq(1)
    end

    it "returns 422 employee_not_eligible for a terminated employee" do
      terminated = employees.find(&:terminated?)

      post "/api/v1/employees/#{terminated.id}/salary_revisions",
           params: { salary_revision: revision.merge(expected_current_salary_record_id: terminated.salary_records.current.first.id) }.to_json,
           headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{write_key}" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_code).to eq("employee_not_eligible")
      expect(json["error"]["details"]).to eq("employment_status" => "terminated")
    end

    it "returns 422 validation_failed with field details" do
      post_revision({ salary_revision: revision.merge(amount: "0.00", reason: " ") })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_code).to eq("validation_failed")
      expect(json["error"]["details"]).to eq("amount" => [ "must be greater than 0" ], "reason" => [ "can't be blank" ])
      expect(json["error"]["message"]).to eq("Amount must be greater than 0")
    end

    it "treats a null field as absent and reports it as validation_failed" do
      post_revision({ salary_revision: revision.merge(amount: nil) })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]["details"]).to eq("amount" => [ "can't be blank" ])
    end

    it "returns 422 validation_failed for more than two decimals, scientific notation and over the maximum" do
      [ "100.123", "1e5", "1000000000.01", "-5", "1,000.00" ].each do |amount|
        post_revision({ salary_revision: revision.merge(amount: amount) })

        expect(response).to have_http_status(:unprocessable_entity), amount
        expect(json["error"]["details"]).to have_key("amount")
      end
    end

    it "returns 422 no_change when amount, currency and frequency match the current salary (DR-10 working default)" do
      post_revision({ salary_revision: revision.merge(amount: "250000.00") })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_code).to eq("no_change")
    end

    it "returns 422 missing_exchange_rate and writes nothing" do
      Currency.create!(code: "JPY", name: "Japanese Yen")

      post_revision({ salary_revision: revision.merge(currency: "JPY") })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_code).to eq("missing_exchange_rate")
      expect(history_size).to eq(1)
      expect(current.reload.effective_to).to be_nil
    end

    it "follows the documented precedence: token (409) before eligibility and validation (422)" do
      terminated = employees.find(&:terminated?)

      post "/api/v1/employees/#{terminated.id}/salary_revisions",
           params: { salary_revision: revision.merge(expected_current_salary_record_id: 0, amount: "bad") }.to_json,
           headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{write_key}" }

      expect(response).to have_http_status(:conflict)
    end
  end

  describe "database and server failures never leak internals" do
    it "maps an unexpected exception to a generic 500" do
      allow(SalaryRevisions::Create).to receive(:call).and_raise(RuntimeError, "PG secret: password=hunter2")
      allow(Rails.logger).to receive(:error)

      post_revision

      expect(response).to have_http_status(:internal_server_error)
      expect(json).to eq("error" => { "code" => "internal_error", "message" => "Something went wrong" })
      expect(response.body).not_to include("hunter2")
    end

    it "maps an overlap violation to 409 revision_conflict without naming the constraint" do
      allow(SalaryRevisions::Create).to receive(:call).and_raise(ActiveRecord::ExclusionViolation.new("salary_records_no_overlap"))

      post_revision

      expect(response).to have_http_status(:conflict)
      expect(error_code).to eq("revision_conflict")
      expect(response.body).not_to include("salary_records_no_overlap")
    end

    it "maps a check, not-null, foreign-key or range violation to 422 validation_failed" do
      [ ActiveRecord::CheckViolation, ActiveRecord::NotNullViolation, ActiveRecord::InvalidForeignKey, ActiveRecord::RangeError ].each do |error|
        allow(SalaryRevisions::Create).to receive(:call).and_raise(error.new("INSERT INTO salary_records ... violates secret_constraint"))

        post_revision

        expect(response).to have_http_status(:unprocessable_entity), error.name
        expect(error_code).to eq("validation_failed")
        expect(response.body).not_to include("secret_constraint")
      end
    end
  end
end
