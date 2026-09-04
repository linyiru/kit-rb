# frozen_string_literal: true

# Integration spec: replays a real recorded Kit API interaction (spec/cassettes).
# Re-record by deleting the cassette and running with a live KIT_API_KEY set.
RSpec.describe "Kit account (VCR)", :vcr do
  it "reads the live account into a typed AccountInfo", vcr: { cassette_name: "account_get" } do
    client = Kit::Client.new(api_key: ENV.fetch("KIT_API_KEY", "test-key"))

    info = client.account.get

    expect(info).to be_a(Kit::Objects::AccountInfo)
    expect(info.account.plan_type).to be_a(String)
    expect(info.user.email).to be_a(String)
  end
end
