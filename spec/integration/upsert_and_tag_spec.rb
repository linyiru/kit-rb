# frozen_string_literal: true

# Integration test for the three-call upsert_and_tag sequence against real Kit
# responses (recorded once, secrets and emails scrubbed, replayed in CI). The
# tag "kit-rb integration" and one subscriber persist in the recording account;
# both calls are idempotent, so re-recording is safe.
RSpec.describe "subscribers.upsert_and_tag (integration)" do
  let(:client) { Kit::Client.new(api_key: ENV.fetch("KIT_API_KEY", "test-key")) }

  it "upserts, ensures the tag once and applies it", vcr: { cassette_name: "integration/upsert_and_tag" } do
    result = client.subscribers.upsert_and_tag(
      email_address: "kit-rb-integration@example.com",
      first_name: "Integration",
      tag_names: ["kit-rb integration", "KIT-RB  integration"] # one tag, matched like Kit does
    )

    expect(result).to be_a(Kit::Objects::TaggedSubscriber)
    expect(result.subscriber).to be_a(Kit::Objects::Subscriber)
    expect(result.subscriber.id).to be_an(Integer)
    expect(result.tags.size).to eq(1)
    expect(result.tags.first).to be_a(Kit::Objects::Tag)
    expect(result.tags.first.id).to be_an(Integer)
    expect(result.tags.first.name).to eq("kit-rb integration")

    # A second ensure is answered from the cache: no fourth request.
    expect(client.tags.ensure(name: "KIT-RB INTEGRATION")).to equal(result.tags.first)
  end
end
