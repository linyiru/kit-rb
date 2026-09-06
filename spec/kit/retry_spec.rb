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

  it "caps Retry-After at max_backoff instead of blocking for the server's full wait" do
    conn = Kit::Connection.new(Kit::Configuration.new(api_key: "k", max_retries: 1, max_backoff: 5))
    allow(conn).to receive(:backoff_sleep)
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_return({ status: 429, headers: { "Retry-After" => "300", "Content-Type" => "application/json" }, body: "{}" },
                 { status: 200, body: "{}", headers: { "Content-Type" => "application/json" } })

    conn.request(:get, "/v4/account")
    expect(conn).to have_received(:backoff_sleep).with(5)
  end

  it "falls back to exponential backoff when Retry-After is not a positive integer" do
    http_date = { "Retry-After" => "Wed, 21 Oct 2026 07:28:00 GMT", "Content-Type" => "application/json" }
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_return({ status: 429, body: "{}", headers: http_date },
                 { status: 200, body: "{}", headers: { "Content-Type" => "application/json" } })

    account_request
    expect(connection).to have_received(:backoff_sleep).with(a_value_between(0.5, 1.0))
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

  it "does not replay a POST after a 5xx, since the server may have applied it" do
    stub = stub_request(:post, "https://api.kit.com/v4/subscribers")
           .to_return(status: 502, body: "{}", headers: { "Content-Type" => "application/json" })

    expect { connection.request(:post, "/v4/subscribers", body: { email_address: "a@b.c" }) }
      .to raise_error(Kit::ServerError)
    expect(stub).to have_been_requested.once
    expect(connection).not_to have_received(:backoff_sleep)
  end

  it "still retries a POST after a 429, which Kit rejected without applying" do
    stub_request(:post, "https://api.kit.com/v4/subscribers")
      .to_return({ status: 429, body: "{}", headers: { "Content-Type" => "application/json" } },
                 { status: 201, body: JSON.generate({ "ok" => true }),
                   headers: { "Content-Type" => "application/json" } })

    expect(connection.request(:post, "/v4/subscribers", body: {})).to eq("ok" => true)
    expect(connection).to have_received(:backoff_sleep).once
  end

  it "retries an idempotent PUT and DELETE after a 5xx" do
    %i[put delete].each do |verb|
      stub_request(verb, "https://api.kit.com/v4/tags/1")
        .to_return({ status: 503, body: "{}", headers: { "Content-Type" => "application/json" } },
                   { status: 200, body: "{}", headers: { "Content-Type" => "application/json" } })
      expect { connection.request(verb, "/v4/tags/1") }.not_to raise_error
    end
    expect(connection).to have_received(:backoff_sleep).twice
  end

  it "reuses one configured HTTP client across requests" do
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
    before = connection.instance_variable_get(:@client)
    2.times { account_request }
    expect(connection.instance_variable_get(:@client)).to equal(before)
    expect(before).to be_a(HTTP::Client)
  end

  it "does not retry a non-transient 4xx" do
    stub = stub_request(:get, "https://api.kit.com/v4/account")
           .to_return(status: 404, body: "{}", headers: { "Content-Type" => "application/json" })
    expect { account_request }.to raise_error(Kit::NotFoundError)
    expect(stub).to have_been_requested.once
  end
end
