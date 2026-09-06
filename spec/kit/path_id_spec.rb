# frozen_string_literal: true

# Ids are interpolated into request paths; they must not be able to rewrite
# the route, and a blank id must fail before any request is made.
RSpec.describe "Resource path ids" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  it "passes integer ids through unchanged" do
    stub = stub_kit(:get, "/v4/subscribers/42", body: { "subscriber" => { "id" => 42 } })
    client.subscribers.get(42)
    expect(stub).to have_been_requested
  end

  it "percent-encodes a String id so it cannot inject path segments or a query" do
    stub = stub_kit(:get, "/v4/subscribers/1%2Funsubscribe%3Fx", body: { "subscriber" => { "id" => 1 } })
    client.subscribers.get("1/unsubscribe?x")
    expect(stub).to have_been_requested
  end

  it "raises ArgumentError on a nil id instead of requesting the list endpoint" do
    expect { client.subscribers.get(nil) }.to raise_error(ArgumentError, /nil or blank/)
    expect(a_request(:get, %r{api.kit.com/v4/subscribers})).not_to have_been_made
  end

  it "raises ArgumentError on a blank id" do
    expect { client.tags.remove_subscriber(3, " ") }.to raise_error(ArgumentError)
  end

  it "encodes every id in a multi-id path" do
    stub = stub_kit(:post, "/v4/tags/a%20b/subscribers/c%2Fd", body: { "subscriber" => { "id" => 1 } })
    client.tags.tag_subscriber("a b", "c/d")
    expect(stub).to have_been_requested
  end
end
