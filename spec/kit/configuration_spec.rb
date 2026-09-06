# frozen_string_literal: true

RSpec.describe Kit::Configuration do
  it "selects the API-key strategy when given an api_key" do
    config = described_class.new(api_key: "secret")
    expect(config.auth).to be_a(Kit::Auth::ApiKey)
    expect(config.auth.headers).to eq("X-Kit-Api-Key" => "secret")
  end

  it "selects the OAuth strategy when given an access_token" do
    config = described_class.new(access_token: "tok")
    expect(config.auth).to be_a(Kit::Auth::OAuth)
    expect(config.auth.headers).to eq("Authorization" => "Bearer tok")
  end

  it "defaults the base URL and timeouts" do
    config = described_class.new(api_key: "k")
    expect(config.base_url).to eq("https://api.kit.com")
    expect(config.open_timeout).to eq(10)
    expect(config.read_timeout).to eq(30)
    expect(config.write_timeout).to eq(30)
  end

  it "raises when no credential is given" do
    expect { described_class.new }.to raise_error(Kit::ConfigurationError, /required/)
  end

  it "raises when both credentials are given" do
    expect { described_class.new(api_key: "k", access_token: "t") }
      .to raise_error(Kit::ConfigurationError, /not both/)
  end

  it "raises when the api_key is blank" do
    expect { described_class.new(api_key: "") }.to raise_error(Kit::ConfigurationError)
  end
end
