require "rails_helper"

RSpec.describe "Unknown routes", type: :request do
  it "returns the contract's 404 body" do
    get "/api/v1/does_not_exist"

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to eq(
      "error" => { "code" => "not_found", "message" => "Not found" }
    )
  end

  it "does not shadow the health check" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
