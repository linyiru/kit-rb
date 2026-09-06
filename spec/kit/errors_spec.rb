# frozen_string_literal: true

RSpec.describe Kit::APIError do
  it "names the request in the default message" do
    error = described_class.new(status: 404, method: :delete, path: "/v4/tags/9")
    expect(error.message).to eq("DELETE /v4/tags/9 failed with status 404")
  end

  it "appends Kit's errors array when present" do
    error = described_class.new(status: 422, body: { "errors" => %w[a b] }, method: :post, path: "/v4/tags")
    expect(error.message).to eq("POST /v4/tags failed with status 422: a, b")
    expect(error.errors).to eq(%w[a b])
  end

  it "falls back to a generic subject when the request is unknown" do
    expect(described_class.new(status: 500).message).to eq("Kit API request failed with status 500")
  end

  it "keeps an explicit message verbatim" do
    expect(described_class.new("custom", status: 400).message).to eq("custom")
  end

  it "carries method and path on a RateLimitError too" do
    error = Kit::RateLimitError.new(status: 429, method: :get, path: "/v4/account", retry_after: 3)
    expect(error.message).to eq("GET /v4/account failed with status 429")
    expect(error.retry_after).to eq(3)
  end
end
