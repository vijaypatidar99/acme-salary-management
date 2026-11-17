require "rails_helper"

# Exercises the error mapping through an anonymous controller: no real endpoint exists yet.
RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      raise error_to_raise
    end

    def error_to_raise
      params.fetch(:error).constantize.new(params[:message])
    end
  end

  def error_body
    response.parsed_body.fetch("error")
  end

  it "maps a missing record to 404 not_found" do
    get :index, params: { error: "ActiveRecord::RecordNotFound" }

    expect(response).to have_http_status(:not_found)
    expect(error_body).to include("code" => "not_found")
  end

  it "maps a malformed request to 400 invalid_request" do
    get :index, params: { error: "ActionController::BadRequest" }

    expect(response).to have_http_status(:bad_request)
    expect(error_body).to include("code" => "invalid_request")
  end

  it "maps an unexpected failure to a generic 500 that leaks nothing" do
    allow(Rails.logger).to receive(:error)

    get :index, params: { error: "RuntimeError", message: "secret SQL: SELECT * FROM salary_records" }

    expect(response).to have_http_status(:internal_server_error)
    expect(error_body).to eq("code" => "internal_error", "message" => "Something went wrong")
    expect(response.body).not_to include("secret", "RuntimeError", "salary_records")
    expect(Rails.logger).to have_received(:error).with(/RuntimeError: unexpected request failure/)
    expect(Rails.logger).not_to have_received(:error).with(/secret SQL/)
  end
end
