require "rails_helper"

RSpec.describe "API input and log safety", type: :request do
  let!(:employees) { create_demo_population }
  let(:employee) { employees.first }
  let(:path) { "/api/v1/employees/#{employee.id}/salary_revisions" }
  let(:write_key) { "review-test-secret" }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{write_key}" } }
  let(:revision) do
    { amount: "270000.00", currency: "INR", pay_frequency: "monthly", reason: "Review",
      expected_current_salary_record_id: employee.current_salary_record.id }
  end

  around do |example|
    original = ENV["DEMO_WRITE_KEY"]
    ENV["DEMO_WRITE_KEY"] = write_key
    example.run
  ensure
    original.nil? ? ENV.delete("DEMO_WRITE_KEY") : ENV["DEMO_WRITE_KEY"] = original
  end

  it "does not coerce a malformed path ID to an existing employee" do
    [ "#{employee.id}junk", "#{employee.id}.5", "#{employee.id}e0" ].each do |id|
      get "/api/v1/employees/#{id}"
      expect(response).to have_http_status(:not_found), id

      post "/api/v1/employees/#{id}/salary_revisions", params: { salary_revision: revision }.to_json, headers: headers
      expect(response).to have_http_status(:not_found), id
    end
    expect(employee.salary_records.count).to eq(1)
  end

  it "validates the body before reporting a malformed employee ID" do
    post "/api/v1/employees/#{employee.id}junk/salary_revisions", params: "{}", headers: headers
    expect(response).to have_http_status(:bad_request)
    expect(json.dig("error", "code")).to eq("invalid_request")
  end

  it "still accepts the explicit JSON representation of an employee" do
    get "/api/v1/employees/#{employee.id}.json"
    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "id")).to eq(employee.id)
  end

  it "rejects PostgreSQL-invalid NUL characters in query parameters with 400" do
    [ [ "/api/v1/employees", { q: "A\0B" } ],
      [ "/api/v1/employees/export.csv", { country: "IN\0" } ],
      [ "/api/v1/analytics/summary", { country: "IN\0" } ] ].each do |url, query|
      get url, params: query
      expect(response).to have_http_status(:bad_request), url
      expect(json.dig("error", "code")).to eq("invalid_parameter")
    end
  end

  it "reports NUL characters in salary input as validation errors without closing history" do
    %i[currency reason].each do |field|
      post path, params: { salary_revision: revision.merge(field => "IN\0R") }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity), field.to_s
      expect(json.dig("error", "code")).to eq("validation_failed")
      expect(json.dig("error", "details")).to have_key(field.to_s)
      expect(employee.current_salary_record.reload.effective_to).to be_nil
    end
    expect(employee.salary_records.count).to eq(1)
  end

  it "does not leak request credentials through an unexpected exception message" do
    supplied = "bad-request-credential"
    allow(SalaryRevisions::Create).to receive(:call).and_raise(RuntimeError, "#{write_key} #{supplied}")
    log = StringIO.new
    logger = ActiveSupport::Logger.new(log)
    allow(Rails).to receive(:logger).and_return(logger)

    post path, params: { salary_revision: revision }.to_json, headers: headers

    expect(response).to have_http_status(:internal_server_error)
    expect(log.string).to include("RuntimeError")
    expect(log.string).not_to include(write_key, supplied)
    expect(response.body).not_to include(write_key, supplied)
  end

  it "filters Authorization values from framework environment diagnostics" do
    request_env = ActionDispatch::TestRequest.create("HTTP_AUTHORIZATION" => "Bearer #{write_key}")
    request_env.set_header("action_dispatch.parameter_filter", Rails.application.config.filter_parameters)

    expect(request_env.filtered_env["HTTP_AUTHORIZATION"]).to eq("[FILTERED]")
  end
end
