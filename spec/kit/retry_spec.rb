# frozen_string_literal: true

RSpec.describe "Connection retries" do
  let(:config) { Kit::Configuration.new(api_key: "k", max_retries: 2) }
  let(:connection) { Kit::Connection.new(config) }

  before { allow(connection).to receive(:backoff_sleep) } # never really sleep

  def account_request = connection.request(:get, "/v4/account")

  it "retries a 429 and returns the eventual success" do
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_return({ status: 429, body: "{}", headers: { "Content-Type" => "application/json" } },
                 { status: 200, body: JSON.generate({ "ok" => true }),
                   headers: { "Content-Type" => "application/json" } })

    expect(account_request).to eq("ok" => true)
    expect(connection).to have_received(:backoff_sleep).once
  end

  it "honours the Retry-After header on a 429" do
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_return({ status: 429, headers: { "Retry-After" => "7", "Content-Type" => "application/json" }, body: "{}" },
                 { status: 200, body: "{}", headers: { "Content-Type" => "application/json" } })

    account_request
    expect(connection).to have_received(:backoff_sleep).with(7)
  end

  it "retries 5xx with exponential backoff" do
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_return({ status: 503, body: "{}", headers: { "Content-Type" => "application/json" } },
                 { status: 200, body: "{}", headers: { "Content-Type" => "application/json" } })

    account_request
    expect(connection).to have_received(:backoff_sleep).once
  end

  it "gives up after max_retries and re-raises the typed error" do
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_return(status: 429, body: JSON.generate({ "errors" => ["nope"] }),
                 headers: { "Content-Type" => "application/json" })

    expect { account_request }.to raise_error(Kit::RateLimitError)
    # initial try + 2 retries = 2 backoff sleeps
    expect(connection).to have_received(:backoff_sleep).twice
  end

  it "does not retry when max_retries is 0" do
    conn = Kit::Connection.new(Kit::Configuration.new(api_key: "k", max_retries: 0))
    allow(conn).to receive(:backoff_sleep)
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_return(status: 503, body: "{}", headers: { "Content-Type" => "application/json" })

    expect { conn.request(:get, "/v4/account") }.to raise_error(Kit::ServerError)
    expect(conn).not_to have_received(:backoff_sleep)
  end

  it "does not retry a non-transient 4xx" do
    stub = stub_request(:get, "https://api.kit.com/v4/account")
           .to_return(status: 404, body: "{}", headers: { "Content-Type" => "application/json" })
    expect { account_request }.to raise_error(Kit::NotFoundError)
    expect(stub).to have_been_requested.once
  end
end
