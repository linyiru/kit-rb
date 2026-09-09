# frozen_string_literal: true

# subscribers.upsert_and_tag — the v4 replacement for v3's tag-subscribe:
# upsert, ensure each tag by name (cached), apply, report what was applied.
RSpec.describe "Kit::Resources::Subscribers#upsert_and_tag" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def respond(status, payload)
    { status: status, headers: { "Content-Type" => "application/json" }, body: JSON.generate(payload) }
  end

  def subscriber_json(id: 500, email: "a@example.com", first_name: nil)
    { "id" => id, "email_address" => email, "first_name" => first_name, "state" => "active" }
  end

  def stub_upsert(email: "a@example.com", first_name: nil, id: 500, status: 200)
    stub_request(:post, "https://api.kit.com/v4/subscribers")
      .with(body: { "email_address" => email, "first_name" => first_name }.compact)
      .to_return(respond(status, "subscriber" => subscriber_json(id: id, email: email, first_name: first_name)))
  end

  def stub_tag_create(name, id:)
    tag = respond(200, "tag" => { "id" => id, "name" => name })
    stub_request(:post, "https://api.kit.com/v4/tags").with(body: { "name" => name }).to_return(tag)
  end

  def stub_tagging(tag_id, subscriber_id: 500, status: 200)
    payload = if status == 200
                { "subscriber" => subscriber_json.merge("tagged_at" => "2026-09-09T00:00:00Z") }
              else
                { "errors" => ["Not found"] }
              end
    stub_request(:post, "https://api.kit.com/v4/tags/#{tag_id}/subscribers/#{subscriber_id}")
      .to_return(respond(status, payload))
  end

  it "upserts, ensures each tag once and applies it, returning what was applied" do
    upsert = stub_upsert(first_name: "Ada")
    vip = stub_tag_create("VIP", id: 1)
    beta = stub_tag_create("beta", id: 2)
    tag_vip = stub_tagging(1)
    tag_beta = stub_tagging(2)

    result = client.subscribers.upsert_and_tag(email_address: "a@example.com", first_name: "Ada",
                                               tag_names: %w[VIP beta])

    expect(result).to be_a(Kit::Objects::TaggedSubscriber)
    expect(result.subscriber.id).to eq(500)
    expect(result.tags.map(&:id)).to eq([1, 2])
    expect(result.tag_names).to eq(%w[VIP beta])
    [upsert, vip, beta, tag_vip, tag_beta].each { |s| expect(s).to have_been_requested.once }
  end

  it "de-duplicates names case-insensitively and by Unicode whitespace, first spelling wins" do
    stub_upsert
    vip = stub_tag_create("VIP customer", id: 1)
    stub_tagging(1)

    result = client.subscribers.upsert_and_tag(email_address: "a@example.com",
                                               tag_names: ["VIP customer", "vip  CUSTOMER", " VIP\u3000customer "])

    expect(result.tags.size).to eq(1)
    expect(result.tag_names).to eq(["VIP customer"])
    expect(vip).to have_been_requested.once
    expect(a_request(:post, "https://api.kit.com/v4/tags/1/subscribers/500")).to have_been_made.once
  end

  it "reuses the client's tag cache across calls (one create per distinct tag per client)" do
    stub_upsert
    stub_upsert(email: "b@example.com", id: 501, status: 201)
    vip = stub_tag_create("vip", id: 1)
    stub_tagging(1)
    stub_tagging(1, subscriber_id: 501)

    client.subscribers.upsert_and_tag(email_address: "a@example.com", tag_names: ["vip"])
    client.subscribers.upsert_and_tag(email_address: "b@example.com", tag_names: ["vip"])
    client.tags.ensure(name: "VIP")

    expect(vip).to have_been_requested.once
  end

  it "shares one Tags resource (and cache) with client.tags even under concurrent first access" do
    clients = Array.new(20) { Kit::Client.new(api_key: "secret") }
    clients.each do |c|
      a = Thread.new { c.tags }
      b = Thread.new { c.subscribers }
      expect(b.value.instance_variable_get(:@tags)).to equal(a.value)
    end
  end

  it "re-ensures once and retries when a cached tag has been deleted (404 on tagging)" do
    stub_upsert
    first = respond(200, "tag" => { "id" => 1, "name" => "vip" })
    again = respond(201, "tag" => { "id" => 9, "name" => "vip" })
    create = stub_request(:post, "https://api.kit.com/v4/tags").with(body: { "name" => "vip" }).to_return(first, again)
    stale = stub_tagging(1, status: 404)
    fresh = stub_tagging(9)

    client.tags.ensure(name: "vip") # warms the cache with the soon-to-be-deleted id 1
    result = client.subscribers.upsert_and_tag(email_address: "a@example.com", tag_names: ["vip"])

    expect(result.tags.map(&:id)).to eq([9])
    expect(create).to have_been_requested.twice
    expect(stale).to have_been_requested.once
    expect(fresh).to have_been_requested.once
    expect(client.tags.ensure(name: "vip").id).to eq(9)
  end

  it "raises the 404 if the tag is still missing after one re-ensure" do
    stub_upsert
    stub_tag_create("vip", id: 1)
    stub_tagging(1, status: 404)

    expect { client.subscribers.upsert_and_tag(email_address: "a@example.com", tag_names: ["vip"]) }
      .to raise_error(Kit::NotFoundError)
    expect(a_request(:post, "https://api.kit.com/v4/tags/1/subscribers/500")).to have_been_made.twice
  end

  it "rejects a blank tag name before any request is made" do
    expect { client.subscribers.upsert_and_tag(email_address: "a@example.com", tag_names: ["vip", " "]) }
      .to raise_error(ArgumentError, /blank/)
    expect(a_request(:any, /api\.kit\.com/)).not_to have_been_made
  end

  it "with no tag names just upserts and applies nothing" do
    stub_upsert
    result = client.subscribers.upsert_and_tag(email_address: "a@example.com", tag_names: [])
    expect(result.tags).to eq([])
    expect(a_request(:post, "https://api.kit.com/v4/tags")).not_to have_been_made
  end

  it "lets a typed error from the upsert propagate before any tagging" do
    stub_request(:post, "https://api.kit.com/v4/subscribers")
      .to_return(respond(422, "errors" => ["Email address is invalid"]))
    expect { client.subscribers.upsert_and_tag(email_address: "nope", tag_names: ["vip"]) }
      .to raise_error(Kit::UnprocessableEntityError)
    expect(a_request(:post, "https://api.kit.com/v4/tags")).not_to have_been_made
  end
end
