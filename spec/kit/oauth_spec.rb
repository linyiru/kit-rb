# frozen_string_literal: true

RSpec.describe Kit::OAuth do
  describe Kit::OAuth::PKCE do
    it "generates an S256 challenge derived from the verifier" do
      c = described_class.generate
      expect(c.code_challenge_method).to eq("S256")
      expect(c.code_verifier).to match(/\A[A-Za-z0-9\-_]{43,128}\z/)
      expect(c.code_challenge).to eq(described_class.challenge_for(c.code_verifier))
      expect(c.code_challenge).not_to include("=") # unpadded base64url
    end

    it "produces distinct verifiers each call" do
      expect(described_class.generate.code_verifier)
        .not_to eq(described_class.generate.code_verifier)
    end
  end

  describe Kit::OAuth::Token do
    it "computes expiry and expired?" do
      token = described_class.from("access_token" => "a", "created_at" => 1000, "expires_in" => 100)
      expect(token.expires_at).to eq(1100)
      expect(token.expired?(now: 1099)).to be(false)
      expect(token.expired?(now: 1100)).to be(true)
      expect(token.expired?(now: 1095, leeway: 10)).to be(true)
    end

    it "is not expired when the fields are absent" do
      expect(described_class.from("access_token" => "a").expired?).to be(false)
    end
  end

  describe Kit::OAuth::Client do
    let(:oauth) do
      described_class.new(client_id: "cid", client_secret: "secret",
                          redirect_uri: "https://app.example/cb")
    end

    it "builds an authorization URL with the expected params" do
      url = oauth.authorization_url(state: "xyz", code_challenge: "chal",
                                    code_challenge_method: "S256")
      q = URI.decode_www_form(URI(url).query).to_h
      expect(url).to start_with("https://api.kit.com/v4/oauth/authorize?")
      expect(q).to include(
        "client_id" => "cid", "response_type" => "code",
        "redirect_uri" => "https://app.example/cb", "scope" => "public",
        "state" => "xyz", "code_challenge" => "chal", "code_challenge_method" => "S256"
      )
    end

    it "omits absent optional params from the authorize URL" do
      q = URI.decode_www_form(URI(oauth.authorization_url).query).to_h
      expect(q).not_to have_key("state")
      expect(q).not_to have_key("code_challenge")
    end

    it "exchanges an authorization code for a Token" do
      stub = stub_request(:post, "https://api.kit.com/v4/oauth/token")
             .with(body: hash_including("grant_type" => "authorization_code",
                                        "code" => "the-code", "client_id" => "cid",
                                        "client_secret" => "secret"))
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("access_token" => "at", "refresh_token" => "rt",
                                            "token_type" => "Bearer", "expires_in" => 3600,
                                            "scope" => "public", "created_at" => 1_700_000_000))

      token = oauth.exchange_code("the-code")
      expect(token).to be_a(Kit::OAuth::Token)
      expect(token.access_token).to eq("at")
      expect(token.refresh_token).to eq("rt")
      expect(stub).to have_been_requested
    end

    it "sends the PKCE code_verifier on exchange" do
      stub = stub_request(:post, "https://api.kit.com/v4/oauth/token")
             .with(body: hash_including("code_verifier" => "verifier-123"))
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("access_token" => "at"))
      oauth.exchange_code("c", code_verifier: "verifier-123")
      expect(stub).to have_been_requested
    end

    it "mints an app-level token via the client_credentials grant" do
      stub = stub_request(:post, "https://api.kit.com/v4/oauth/token")
             .with(body: hash_including("grant_type" => "client_credentials",
                                        "client_id" => "cid", "client_secret" => "secret"))
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("access_token" => "app-at", "token_type" => "Bearer",
                                            "expires_in" => 172_799, "scope" => "public",
                                            "created_at" => 1_700_000_000))

      token = oauth.client_credentials
      expect(token).to be_a(Kit::OAuth::Token)
      expect(token.access_token).to eq("app-at")
      expect(token.refresh_token).to be_nil
      expect(stub).to have_been_requested
    end

    it "passes an explicit scope on the client_credentials grant" do
      stub = stub_request(:post, "https://api.kit.com/v4/oauth/token")
             .with(body: hash_including("grant_type" => "client_credentials", "scope" => "public"))
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("access_token" => "app-at"))
      oauth.client_credentials(scope: "public")
      expect(stub).to have_been_requested
    end

    it "refreshes and returns the new single-use refresh_token" do
      stub_request(:post, "https://api.kit.com/v4/oauth/token")
        .with(body: hash_including("grant_type" => "refresh_token", "refresh_token" => "old-rt"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate("access_token" => "new-at", "refresh_token" => "new-rt"))

      token = oauth.refresh("old-rt")
      expect(token.access_token).to eq("new-at")
      expect(token.refresh_token).to eq("new-rt")
    end

    it "revokes a token and returns true on 200 (empty body)" do
      stub = stub_request(:post, "https://api.kit.com/v4/oauth/revoke")
             .with(body: hash_including("token" => "the-token", "client_id" => "cid",
                                        "client_secret" => "secret",
                                        "token_type_hint" => "refresh_token"))
             .to_return(status: 200, body: "")
      expect(oauth.revoke("the-token", token_type_hint: "refresh_token")).to be(true)
      expect(stub).to have_been_requested
    end

    it "omits token_type_hint when not given" do
      stub = stub_request(:post, "https://api.kit.com/v4/oauth/revoke")
             .with { |req| !req.body.include?("token_type_hint") }
             .to_return(status: 200, body: "")
      expect(oauth.revoke("t")).to be(true)
      expect(stub).to have_been_requested
    end

    it "raises OAuthError when revocation fails" do
      stub_request(:post, "https://api.kit.com/v4/oauth/revoke")
        .to_return(status: 401, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate("error" => "invalid_client"))
      expect { oauth.revoke("t") }.to raise_error(Kit::OAuthError) do |e|
        expect(e.status).to eq(401)
        expect(e.oauth_error).to eq("invalid_client")
      end
    end

    it "raises OAuthError with the RFC 6749 error code on failure" do
      stub_request(:post, "https://api.kit.com/v4/oauth/token")
        .to_return(status: 400, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate("error" => "invalid_grant",
                                       "error_description" => "code expired"))
      expect { oauth.exchange_code("bad") }.to raise_error(Kit::OAuthError) do |e|
        expect(e.oauth_error).to eq("invalid_grant")
        expect(e.error_description).to eq("code expired")
        expect(e.status).to eq(400)
      end
    end

    it "requires a client_id" do
      expect { described_class.new(client_id: "") }.to raise_error(Kit::ConfigurationError)
    end
  end
end
