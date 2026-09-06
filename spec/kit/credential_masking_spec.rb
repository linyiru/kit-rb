# frozen_string_literal: true

# Credentials must never appear in #inspect output: clients, configs, and
# tokens routinely end up in log lines and exception messages.
RSpec.describe "Credential masking" do
  let(:key) { "kit_live_0123456789abcdef" }

  it "masks the API key in the client, its config, and the auth strategy" do
    client = Kit::Client.new(api_key: key)
    connection = client.instance_variable_get(:@connection)
    [client, client.config, client.config.auth, connection].each do |object|
      expect(object.inspect).not_to include(key)
      expect(object.inspect).to include("****cdef")
    end
  end

  it "masks the OAuth access token in the client" do
    client = Kit::Client.new(access_token: "oauth-secret-token-xyz9")
    expect(client.inspect).not_to include("oauth-secret-token")
    expect(client.inspect).to include("****xyz9")
  end

  it "masks both tokens in OAuth::Token#inspect but keeps them in #to_h" do
    token = Kit::OAuth::Token.from("access_token" => "access-secret-1234", "refresh_token" => "refresh-secret-5678",
                                   "token_type" => "Bearer", "expires_in" => 3600, "scope" => "public",
                                   "created_at" => 1)
    expect(token.inspect).not_to include("access-secret", "refresh-secret")
    expect(token.inspect).to include("****1234").and include("****5678").and include("Bearer")
    expect(token.to_h).to include(access_token: "access-secret-1234", refresh_token: "refresh-secret-5678")
    expect(token.to_s).to eq(token.inspect)
  end

  it "fully masks short secrets and prints nil as nil" do
    expect(Kit::Auth::Credential.mask("short")).to eq("****")
    expect(Kit::Auth::Credential.mask(nil)).to eq("nil")
    expect(Kit::OAuth::Token.from({}).inspect).to include("refresh_token=nil")
  end
end
