require "rails_helper"

RSpec.describe "CORS", type: :request do
  def preflight(path, origin:)
    options path, headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "POST",
      "Access-Control-Request-Headers" => "authorization,content-type"
    }
  end

  it "allows the local Vite dev origin, including the Authorization header" do
    preflight "/api/v1/anything", origin: "http://localhost:5173"

    expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:5173")
    expect(response.headers["Access-Control-Allow-Headers"].downcase).to include("authorization")
  end

  it "does not allow other origins" do
    preflight "/api/v1/anything", origin: "https://evil.example"

    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end

  it "echoes the one allowed origin on simple requests instead of a wildcard" do
    get "/up", headers: { "Origin" => "http://localhost:5173" }

    expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:5173")
  end

  it "refuses wildcard environment configuration instead of opening every origin" do
    original = ENV["CORS_ALLOWED_ORIGINS"]
    [ "*", "https://hr.example,*" ].each do |origins|
      ENV["CORS_ALLOWED_ORIGINS"] = origins
      expect { load Rails.root.join("config/initializers/cors.rb") }.to raise_error(ArgumentError, /explicit origins/)
    end
  ensure
    original.nil? ? ENV.delete("CORS_ALLOWED_ORIGINS") : ENV["CORS_ALLOWED_ORIGINS"] = original
  end
end
