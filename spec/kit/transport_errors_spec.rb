# frozen_string_literal: true

RSpec.describe "Transport errors" do
  let(:connection) { Kit::Connection.new(Kit::Configuration.new(api_key: "k", max_retries: 1)) }

  before { allow(connection).to receive(:backoff_sleep) }

  it "maps a timeout to Kit::TimeoutError, naming the request, with the cause attached" do
    stub_request(:get, "https://api.kit.com/v4/account").to_timeout
    expect { Kit::Connection.new(Kit::Configuration.new(api_key: "k", max_retries: 0)).request(:get, "/v4/account") }
      .to raise_error(Kit::TimeoutError, %r{GET /v4/account timed out}) do |e|
      expect(e).to be_a(Kit::TransportError).and be_a(Kit::Error)
      expect(e.cause).to be_a(HTTP::TimeoutError)
    end
  end

  it "maps a dropped connection to Kit::ConnectionError" do
    stub_request(:get, "https://api.kit.com/v4/account").to_raise(HTTP::ConnectionError.new("refused"))
    expect { Kit::Connection.new(Kit::Configuration.new(api_key: "k", max_retries: 0)).request(:get, "/v4/account") }
      .to raise_error(Kit::ConnectionError, /could not connect: refused/)
  end

  it "retries a transport failure on an idempotent request" do
    stub_request(:get, "https://api.kit.com/v4/account")
      .to_timeout
      .then.to_return(status: 200, body: JSON.generate({ "ok" => true }),
                      headers: { "Content-Type" => "application/json" })
    expect(connection.request(:get, "/v4/account")).to eq("ok" => true)
    expect(connection).to have_received(:backoff_sleep).once
  end

  it "does not retry a transport failure on a POST" do
    stub = stub_request(:post, "https://api.kit.com/v4/tags").to_timeout
    expect { connection.request(:post, "/v4/tags", body: { name: "x" }) }.to raise_error(Kit::TimeoutError)
    expect(stub).to have_been_requested.once
    expect(connection).not_to have_received(:backoff_sleep)
  end
end
