# frozen_string_literal: true

RSpec.describe Kit::Resources::Account do
  # max_retries: 0 — these specs assert the error mapping, not the retry policy
  # (retry_spec.rb covers that), so a 429/5xx must not really sleep.
  let(:client) { Kit::Client.new(api_key: "secret", max_retries: 0) }

  describe "#get" do
    it "returns a typed AccountInfo and sends the API-key header" do
      stub = stub_kit(:get, "/v4/account", body: {
                        "user" => { "email" => "creator@example.com", "id" => 1 },
                        "account" => {
                          "id" => 99, "name" => "Acme", "plan_type" => "creator_pro",
                          "primary_email_address" => "billing@example.com",
                          "created_at" => "2026-01-01T00:00:00Z"
                        }
                      })

      info = client.account.get

      expect(info).to be_a(Kit::Objects::AccountInfo)
      expect(info.user.email).to eq("creator@example.com")
      expect(info.account.plan_type).to eq("creator_pro")
      expect(info.account.id).to eq(99)
      expect(stub.with(headers: { "X-Kit-Api-Key" => "secret" })).to have_been_requested
    end

    it "tolerates unknown account fields (forward-compatible)" do
      stub_kit(:get, "/v4/account", body: {
                 "user" => { "email" => "e@x.com" },
                 "account" => { "id" => 1, "some_new_field" => "ignored" }
               })
      expect { client.account.get }.not_to raise_error
    end

    it "sends a Bearer header when using OAuth" do
      oauth = Kit::Client.new(access_token: "tok")
      stub = stub_kit(:get, "/v4/account", body: { "user" => { "email" => "e@x.com" }, "account" => {} })
      oauth.account.get
      expect(stub.with(headers: { "Authorization" => "Bearer tok" })).to have_been_requested
    end
  end

  describe "error mapping" do
    {
      401 => Kit::AuthenticationError,
      403 => Kit::AuthorizationError,
      404 => Kit::NotFoundError,
      409 => Kit::ConflictError,
      413 => Kit::PayloadTooLargeError,
      422 => Kit::UnprocessableEntityError,
      500 => Kit::ServerError
    }.each do |status, klass|
      it "raises #{klass} on #{status}" do
        stub_kit(:get, "/v4/account", status: status, body: { "errors" => ["boom"] })
        expect { client.account.get }.to raise_error(klass) do |e|
          expect(e.status).to eq(status)
          expect(e.errors).to eq(["boom"])
          expect(e.method).to eq(:get)
          expect(e.path).to eq("/v4/account")
          expect(e.message).to eq("GET /v4/account failed with status #{status}: boom")
        end
      end
    end

    it "raises RateLimitError with retry_after on 429" do
      stub_request(:get, "https://api.kit.com/v4/account")
        .to_return(status: 429, headers: { "Retry-After" => "30", "Content-Type" => "application/json" },
                   body: JSON.generate({ "errors" => ["slow down"] }))
      expect { client.account.get }.to raise_error(Kit::RateLimitError) do |e|
        expect(e.retry_after).to eq(30)
      end
    end
  end
end
