# frozen_string_literal: true

RSpec.describe Kit::Resources::Tags do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def tag(id:, name: "vip", count: 3)
    { "id" => id, "name" => name, "created_at" => "2026-01-01T00:00:00Z",
      "subscriber_count" => count }
  end

  def sub(id:) = { "id" => id, "email_address" => "s#{id}@x.com", "state" => "active" }

  def tag_page(tags, has_next: false)
    { "tags" => tags,
      "pagination" => { "has_previous_page" => false, "has_next_page" => has_next,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed Tag" do
      stub_kit(:get, "/v4/tags", body: tag_page([tag(id: 1), tag(id: 2)]))
      list = client.tags.list
      expect(list).to be_a(Kit::Collection)
      expect(list.map(&:name)).to eq(%w[vip vip])
      expect(list.first).to be_a(Kit::Objects::Tag)
    end
  end

  describe "#create" do
    it "posts the name and returns a Tag" do
      stub = stub_request(:post, "https://api.kit.com/v4/tags")
             .with(body: { "name" => "launch" })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("tag" => tag(id: 9, name: "launch")))
      expect(client.tags.create(name: "launch")).to be_a(Kit::Objects::Tag)
      expect(stub).to have_been_requested
    end
  end

  describe ".normalize_name / .name_key" do
    it "collapses runs of Unicode whitespace to one space and trims" do
      expect(described_class.normalize_name("  VIP\u3000\u00a0customer\t ")).to eq("VIP customer")
    end

    it "keys case-insensitively, as Kit matches names" do
      expect(described_class.name_key("VIP")).to eq(described_class.name_key("vip"))
      expect(described_class.name_key("Straße")).to eq("straße")
    end

    it "rejects a name that is blank after normalisation" do
      expect { described_class.normalize_name(" \u3000 ") }.to raise_error(ArgumentError, /blank/)
      expect { described_class.normalize_name(nil) }.to raise_error(ArgumentError, /blank/)
    end
  end

  describe "#ensure" do
    def stub_create(name, id:, status: 200)
      stub_request(:post, "https://api.kit.com/v4/tags")
        .with(body: { "name" => name })
        .to_return(status: status, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate("tag" => tag(id: id, name: name)))
    end

    it "creates once and answers from the cache for the same name, regardless of case or spacing" do
      stub = stub_create("VIP customer", id: 7)
      first = client.tags.ensure(name: "VIP customer")
      expect(client.tags.ensure(name: "vip  CUSTOMER")).to equal(first)
      expect(client.tags.ensure(name: " VIP\u3000customer ")).to equal(first)
      expect(first.id).to eq(7)
      expect(stub).to have_been_requested.once
    end

    it "sends the normalised name, not the raw one" do
      stub = stub_create("Launch 2026", id: 8, status: 201)
      client.tags.ensure(name: "  Launch\u00a0\u00a02026 ")
      expect(stub).to have_been_requested.once
    end

    it "caches per client, not globally" do
      stub = stub_create("vip", id: 1)
      client.tags.ensure(name: "vip")
      Kit::Client.new(api_key: "other").tags.ensure(name: "vip")
      expect(stub).to have_been_requested.twice
    end

    it "refresh: true drops the cached entry and asks Kit again" do
      stub = stub_create("vip", id: 1)
      client.tags.ensure(name: "vip")
      client.tags.ensure(name: "vip", refresh: true)
      client.tags.ensure(name: "vip")
      expect(stub).to have_been_requested.twice
    end

    it "does not cache a failure" do
      stub_request(:post, "https://api.kit.com/v4/tags")
        .to_return({ status: 500, body: "{}", headers: { "Content-Type" => "application/json" } },
                   { status: 201, headers: { "Content-Type" => "application/json" },
                     body: JSON.generate("tag" => tag(id: 2, name: "vip")) })
      client = Kit::Client.new(api_key: "secret", max_retries: 0)
      expect { client.tags.ensure(name: "vip") }.to raise_error(Kit::ServerError)
      expect(client.tags.ensure(name: "vip").id).to eq(2)
    end

    it "forgets a renamed tag's old name and remembers the new one (update)" do
      stub_create("vip", id: 1)
      renamed_json = { status: 200, headers: { "Content-Type" => "application/json" },
                       body: JSON.generate("tag" => tag(id: 1, name: "premium")) }
      stub_request(:put, "https://api.kit.com/v4/tags/1").with(body: { "name" => "premium" }).to_return(renamed_json)
      fresh = stub_create("vip", id: 2, status: 201)

      client.tags.ensure(name: "vip")
      renamed = client.tags.update(1, name: "premium")

      expect(client.tags.ensure(name: "PREMIUM")).to equal(renamed)   # cached under the new name, no request
      expect(client.tags.ensure(name: "vip").id).to eq(2)             # old name asks Kit again
      expect(fresh).to have_been_requested.once
    end

    it "does not let an in-flight ensure re-insert an old name over a concurrent rename" do
      created = Queue.new
      renamed = Queue.new
      json = { "Content-Type" => "application/json" }
      first = { status: 200, headers: json, body: JSON.generate("tag" => tag(id: 1)) }
      second = { status: 201, headers: json, body: JSON.generate("tag" => tag(id: 2)) }
      creates = stub_request(:post, "https://api.kit.com/v4/tags").with(body: { "name" => "vip" })
                                                                  .to_return(first, second)
      stub_request(:put, "https://api.kit.com/v4/tags/1")
        .to_return(status: 200, headers: json, body: JSON.generate("tag" => tag(id: 1, name: "premium")))

      tags = client.tags
      allow(tags).to receive(:create).and_wrap_original do |original, **kw|
        result = original.call(**kw)
        if kw[:name] == "vip" && created.empty? && result.id == 1
          created << true
          renamed.pop # pause between Kit's answer and publishing it, while a rename runs
        end
        result
      end

      in_flight = Thread.new { tags.ensure(name: "vip") }
      created.pop
      tags.update(1, name: "premium")
      renamed << true
      expect(in_flight.value.id).to eq(1)                # the answer Kit gave at the time

      expect(tags.ensure(name: "premium").id).to eq(1)   # from cache
      expect(tags.ensure(name: "vip").id).to eq(2)       # not the stale id 1: asks Kit again
      expect(creates).to have_been_requested.twice
    end

    it "is safe under concurrent first use: one Tag wins and every caller gets it" do
      stub_create("vip", id: 3)
      tags = client.tags
      arrived = Queue.new
      go = Queue.new
      # Barrier: every thread completes its create before any may publish, so
      # this is a real concurrent miss, not eight sequential cache hits.
      allow(tags).to receive(:create).and_wrap_original do |original, **kw|
        result = original.call(**kw)
        arrived << true
        go.pop
        result
      end

      threads = Array.new(8) { Thread.new { tags.ensure(name: "vip") } }
      8.times { arrived.pop }
      8.times { go << true }
      results = threads.map(&:value)

      expect(results.uniq(&:object_id).size).to eq(1)
      expect(results.first.id).to eq(3)
      expect(tags.ensure(name: "vip")).to equal(results.first)
    end

    it "does not let an ensure that started before refresh: true repopulate the evicted entry" do
      json = { "Content-Type" => "application/json" }
      first = { status: 200, headers: json, body: JSON.generate("tag" => tag(id: 1)) }
      second = { status: 201, headers: json, body: JSON.generate("tag" => tag(id: 2)) }
      creates = stub_request(:post, "https://api.kit.com/v4/tags").with(body: { "name" => "vip" })
                                                                  .to_return(first, second)
      tags = client.tags
      answered = Queue.new
      release = { 1 => Queue.new, 2 => Queue.new }
      # Both creates are held after Kit answers, so publication order is ours:
      # the stale (pre-refresh) response publishes first, then the fresh one.
      allow(tags).to receive(:create).and_wrap_original do |original, **kw|
        result = original.call(**kw)
        answered << result.id
        release.fetch(result.id).pop
        result
      end

      stale = Thread.new { tags.ensure(name: "vip") }
      expect(answered.pop).to eq(1)
      fresh = Thread.new { tags.ensure(name: "vip", refresh: true) } # evicts id 1, asks Kit
      expect(answered.pop).to eq(2)
      release[1] << true
      expect(stale.value.id).to eq(1) # what Kit said at the time: returned to its caller, not cached
      release[2] << true
      expect(fresh.value.id).to eq(2)

      expect(tags.ensure(name: "vip").id).to eq(2) # not repopulated with the deleted id 1
      expect(creates).to have_been_requested.twice
    end
  end

  describe "#update" do
    it "puts the new name" do
      stub_kit(:put, "/v4/tags/9", body: { "tag" => tag(id: 9, name: "renamed") })
      expect(client.tags.update(9, name: "renamed").name).to eq("renamed")
    end
  end

  describe "#tag_subscriber / #remove_subscriber" do
    it "tags a subscriber by id and returns the Subscriber" do
      stub_kit(:post, "/v4/tags/9/subscribers/42", body: { "subscriber" => sub(id: 42) })
      expect(client.tags.tag_subscriber(9, 42)).to be_a(Kit::Objects::Subscriber)
    end

    it "removes a tag from a subscriber" do
      stub = stub_kit(:delete, "/v4/tags/9/subscribers/42", body: {})
      client.tags.remove_subscriber(9, 42)
      expect(stub).to have_been_requested
    end
  end

  describe "#tag_subscriber_by_email / #remove_subscriber_by_email" do
    it "tags a subscriber by email" do
      stub = stub_request(:post, "https://api.kit.com/v4/tags/9/subscribers")
             .with(body: { "email_address" => "s5@x.com" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("subscriber" => sub(id: 5)))
      expect(client.tags.tag_subscriber_by_email(9, email_address: "s5@x.com")).to be_a(Kit::Objects::Subscriber)
      expect(stub).to have_been_requested
    end

    it "removes a tag from a subscriber by email (query param)" do
      stub = stub_request(:delete, "https://api.kit.com/v4/tags/9/subscribers")
             .with(query: { "email_address" => "s5@x.com" })
             .to_return(status: 204, body: "")
      expect(client.tags.remove_subscriber_by_email(9, email_address: "s5@x.com")).to be_nil
      expect(stub).to have_been_requested
    end
  end

  describe "#subscribers" do
    it "returns a Collection of Subscriber tagged with this tag" do
      stub_kit(:get, "/v4/tags/9/subscribers",
               body: { "subscribers" => [sub(id: 1)],
                       "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                                         "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } })
      list = client.tags.subscribers(9)
      expect(list.first).to be_a(Kit::Objects::Subscriber)
    end
  end
end
