# frozen_string_literal: true

require "kit/testing"

RSpec.describe Kit::Testing do
  describe ".response" do
    it "returns Kit's documented example body for an operation, deep-copied" do
      first = described_class.response(:subscribers_get)
      second = described_class.response(:subscribers_get)

      expect(first).to eq(second)
      expect(first).not_to equal(second)
      first["subscriber"]["fields"]["mutated"] = true
      expect(second["subscriber"]["fields"]).not_to have_key("mutated")
    end

    it "applies overrides to the envelope object, with Symbol or String keys" do
      body = described_class.response(:subscribers_get, id: 500, "email_address" => "ada@example.com")
      expect(body["subscriber"]).to include("id" => 500, "email_address" => "ada@example.com", "state" => "active")
    end

    it "selects among the documented 2xx bodies with http_status:" do
      expect(described_class.response(:subscribers_create, http_status: 201)).to have_key("subscriber")
      expect(described_class.response(:subscribers_create, http_status: 202)).to have_key("subscriber")
      expect { described_class.response(:subscribers_create, http_status: 204) }
        .to raise_error(ArgumentError, /documents 200, 201, 202/)
    end

    it "keeps status: available as the documented field of posts, purchases, broadcasts and webhook endpoints" do
      expect(described_class.post_json(status: "draft")["post"]["status"]).to eq("draft")
      expect(described_class.purchase_json(status: "refunded")["purchase"]["status"]).to eq("refunded")
      expect(described_class.response(:webhook_endpoints_get, http_status: 200, status: "paused")
        .dig("webhook_endpoint", "status")).to eq("paused")
    end

    it "rejects a field of a different response type that shares the envelope key" do
      # "stats" wraps three objects; "broadcast" wraps a Broadcast or BroadcastStats.
      expect { described_class.email_stats_json(net_new_subscribers: 1) }
        .to raise_error(ArgumentError, /"net_new_subscribers" is not a field of "email_stats"/)
      expect(described_class.growth_stats_json(net_new_subscribers: 1).dig("stats", "net_new_subscribers")).to eq(1)
      expect { described_class.broadcast_json(stats: {}) }.to raise_error(ArgumentError, /not a field of "broadcast"/)
      expect(described_class.broadcast_stats_json(stats: { "recipients" => 5 }).dig("broadcast", "stats",
                                                                                    "recipients")).to eq(5)
    end

    it "rejects a field Kit never documents for that envelope (a typo)" do
      expect { described_class.response(:tags_create, nmae: "vip") }
        .to raise_error(ArgumentError, /"nmae" is not a field of "tag"; known: created_at, id, name/)
    end

    it "accepts a field documented for the envelope even when the canonical example omits it" do
      # tagged_at appears on the tag_subscriber example, not on GET /v4/subscribers/{id}
      expect(described_class.attributes(:subscribers_get)).not_to have_key("tagged_at")
      subscriber = described_class.response(:subscribers_get, tagged_at: "2026-09-09T00:00:00Z")["subscriber"]
      expect(subscriber["tagged_at"]).to eq("2026-09-09T00:00:00Z")
    end

    it "rejects an unknown operation" do
      expect { described_class.response(:subscribers_frobnicate) }
        .to raise_error(ArgumentError, /unknown Kit operation :subscribers_frobnicate/)
    end

    it "rejects overrides on a body with no envelope object (colors, bulk, 204)" do
      expect do
        described_class.response(:account_colors, colors: [])
      end.to raise_error(ArgumentError, /no envelope object/)
      expect do
        described_class.response(:custom_fields_delete, id: 1)
      end.to raise_error(ArgumentError, /no envelope object/)
      expect(described_class.response(:custom_fields_delete)).to be_nil
      expect(described_class.response(:account_colors)).to eq("colors" => ["#008000", "#FF0000"])
    end

    it "overrides the first item of a paginated list" do
      body = described_class.response(:tags_list, name: "vip")
      expect(body["tags"].first["name"]).to eq("vip")
      expect(body).to have_key("pagination")
    end
  end

  describe ".attributes" do
    it "returns the bare envelope object, ready for Objects::*.from" do
      attrs = described_class.attributes(:subscribers_get, first_name: "Ada")
      expect(attrs).not_to have_key("subscriber")
      expect(Kit::Objects::Subscriber.from(attrs).first_name).to eq("Ada")
    end

    it "returns the example item for a list operation" do
      expect(described_class.attributes(:tags_list)).to include("id", "name")
    end

    it "refuses an operation with no envelope object" do
      expect { described_class.attributes(:account_colors) }.to raise_error(ArgumentError, /no envelope object/)
    end
  end

  describe ".list_json" do
    it "builds a page from override rows, each merged over the example item" do
      body = described_class.list_json(:tags_list, [{ name: "vip" }, { id: 9, name: "beta" }])
      expect(body["tags"].map { |t| t["name"] }).to eq(%w[vip beta])
      expect(body["tags"][1]["id"]).to eq(9)
      expect(body["tags"]).to all(include("created_at"))
    end

    it "builds n example items with distinct ids from an Integer, keeping the documented id type" do
      body = described_class.list_json(:subscribers_list, 3)
      expect(body["subscribers"].map { |s| s["id"] }.uniq.size).to eq(3)
      expect(body["subscribers"]).to all(include("id" => an_instance_of(Integer)))

      filtered = described_class.list_json(:subscribers_filter, 2)["subscribers"] # documents string ids
      expect(filtered.map { |s| s["id"] }).to all(be_a(String))
      expect(filtered.map { |s| s["id"] }.uniq.size).to eq(2)
    end

    it "deep-copies override values, so rows sharing one override Hash stay independent and nothing stays frozen" do
      shared = { "category" => "One" }
      rows = described_class.list_json(:subscribers_list, [{ fields: shared }, { fields: shared }])["subscribers"]
      rows[0]["fields"]["mutated"] = true
      expect(rows[1]["fields"]).to eq("category" => "One")
      expect(shared).to eq("category" => "One")

      tag = described_class.tag_json(name: "vip")["tag"]
      expect(tag["name"]).not_to be_frozen
    end

    it "gives every generated row its own nested data" do
      rows = described_class.list_json(:subscribers_list, 2)["subscribers"]
      rows[0]["fields"]["mutated"] = true
      expect(rows[1]["fields"]).not_to have_key("mutated")

      rows = described_class.list_json(:subscribers_list, [{ first_name: "A" }, { first_name: "B" }])["subscribers"]
      rows[0]["fields"]["mutated"] = true
      expect(rows[1]["fields"]).not_to have_key("mutated")
    end

    it "sets pagination from keywords, keeping the example's other fields" do
      page = described_class.list_json(:tags_list, 1, has_next_page: true, end_cursor: "E", per_page: 10,
                                                      total_count: 42)["pagination"]
      expect(page).to include("has_next_page" => true, "has_previous_page" => false, "end_cursor" => "E",
                              "per_page" => 10, "total_count" => 42)
      expect(page).to have_key("start_cursor")
    end

    it "builds an empty page with null cursors, as the real API answers" do
      body = described_class.list_json(:tags_list, [])
      expect(body["tags"]).to eq([])
      expect(body["pagination"]).to include("start_cursor" => nil, "end_cursor" => nil, "has_next_page" => false)
    end

    it "distinguishes an omitted pagination keyword from an explicit nil" do
      kept = described_class.list_json(:tags_list, 1)["pagination"]
      expect(kept["end_cursor"]).to be_a(String)
      cleared = described_class.list_json(:tags_list, 1, end_cursor: nil)["pagination"]
      expect(cleared).to include("end_cursor" => nil)
      expect(cleared["start_cursor"]).to be_a(String)
      expect(described_class.list_json(:tags_list, [], end_cursor: "E")["pagination"]["end_cursor"]).to eq("E")
    end

    it "pagination_json alone replaces only the fields given, keeping the example's page flags" do
      filtered = described_class::Fixtures.for(:subscribers_filter)["responses"]["200"]["pagination"]
      expect(filtered["has_next_page"]).to be(true)
      expect(described_class.pagination_json(filtered)["has_next_page"]).to be(true)
      expect(described_class.pagination_json(filtered, has_next_page: false)["has_next_page"]).to be(false)
      # list_json, by contrast, builds a terminal page unless told otherwise
      expect(described_class.list_json(:subscribers_filter, 1)["pagination"]["has_next_page"]).to be(false)
    end

    it "rejects an unknown pagination keyword" do
      expect { described_class.list_json(:tags_list, 1, has_nxt_page: true) }
        .to raise_error(ArgumentError, /unknown pagination field\(s\) \[:has_nxt_page\]/)
    end

    it "is what the client parses into a Collection" do
      stub_request(:get, "https://api.kit.com/v4/tags")
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate(described_class.list_json(:tags_list, [{ name: "vip" }], has_next_page: true)))
      list = Kit::Client.new(api_key: "k").tags.list
      expect(list.map(&:name)).to eq(["vip"])
      expect(list.pagination.has_next_page).to be(true)
    end

    it "refuses a non-list operation and a typo in a row" do
      expect { described_class.list_json(:subscribers_get) }.to raise_error(ArgumentError, /not a paginated list/)
      expect { described_class.list_json(:tags_list, [{ nmae: "x" }]) }.to raise_error(ArgumentError, /"nmae"/)
    end
  end

  describe "object builders" do
    it "defines one <object>_json per OBJECTS entry, wrapping the canonical operation's envelope" do
      described_class::OBJECTS.each do |object, operation|
        body = described_class.public_send(:"#{object}_json")
        expect(body).to eq(described_class.response(operation)), object
        expect(body.keys).to include(described_class::FIXTURES.fetch(operation.to_s).fetch("key"))
      end
    end

    it "builds every single-object envelope the resources parse, end to end" do
      {
        subscriber_json: [:subscribers, :get, 1, Kit::Objects::Subscriber],
        tag_json: [:tags, :update, 1, Kit::Objects::Tag],
        custom_field_json: [:custom_fields, :update, 1, Kit::Objects::CustomField],
        sequence_json: [:sequences, :get, 1, Kit::Objects::Sequence],
        broadcast_json: [:broadcasts, :get, 1, Kit::Objects::Broadcast],
        post_json: [:posts, :get, 1, Kit::Objects::Post],
        snippet_json: [:snippets, :get, 1, Kit::Objects::Snippet],
        purchase_json: [:purchases, :get, 1, Kit::Objects::Purchase],
        webhook_endpoint_json: [:webhook_endpoints, :get, 1, Kit::Objects::WebhookEndpoint]
      }.each do |builder, (resource, method, id, klass)|
        path = { tags: "/v4/tags/1", custom_fields: "/v4/custom_fields/1" }.fetch(resource, "/v4/#{resource}/1")
        verb = method == :update ? :put : :get
        stub_request(verb, "https://api.kit.com#{path}")
          .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                     body: JSON.generate(described_class.public_send(builder, id: 77)))
        args = if method == :update
                 [id, { resource == :tags ? :name : :label => "x" }]
               else
                 [id]
               end
        object = Kit::Client.new(api_key: "k").public_send(resource).public_send(method, *args[0..0], **(args[1] || {}))
        expect(object).to be_a(klass), builder
        expect(object.id).to eq(77), builder
      end
    end

    it "account_json overrides the account and parses into AccountInfo" do
      stub_request(:get, "https://api.kit.com/v4/account")
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate(described_class.account_json(plan_type: "free", name: "")))
      info = Kit::Client.new(api_key: "k").account.get
      expect(info.account.plan_type).to eq("free")
      expect(info.account.name).to eq("")
      expect(info.user.email).to be_a(String)
    end
  end

  describe ".error_json" do
    it "builds Kit's errors envelope from one or many messages" do
      expect(described_class.error_json("The API key is invalid")).to eq("errors" => ["The API key is invalid"])
      expect(described_class.error_json(%w[a b])).to eq("errors" => %w[a b])
    end

    it "is what the client raises a typed error from" do
      stub_request(:get, "https://api.kit.com/v4/account")
        .to_return(status: 401, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate(described_class.error_json("The API key is invalid")))
      expect { Kit::Client.new(api_key: "bad").account.get }
        .to raise_error(Kit::AuthenticationError, /The API key is invalid/)
    end
  end

  describe ".http_status / .operation" do
    it "reports the documented default and validates a chosen status" do
      expect(described_class.http_status(:tags_create)).to eq(200)
      expect(described_class.http_status(:tags_create, 201)).to eq(201)
      expect(described_class.http_status(:custom_fields_delete)).to eq(204)
      expect { described_class.http_status(:tags_create, 418) }.to raise_error(ArgumentError)
    end

    it "exposes the verb and templated path of an operation" do
      expect(described_class.operation(:tags_tag_subscriber)).to eq([:post, "/v4/tags/{tag_id}/subscribers/{id}"])
      expect(described_class.operation("account_get")).to eq([:get, "/v4/account"])
    end
  end

  describe "shared state" do
    it "hands out frozen registry tuples, so a caller cannot corrupt OPERATIONS" do
      tuple = described_class.operation(:tags_create)
      expect(tuple).to be_frozen
      expect { tuple[0] = :delete }.to raise_error(FrozenError)
      expect(described_class::OPERATIONS[:tags_create]).to eq([:post, "/v4/tags"])
    end

    it "deep-freezes the fixtures, so reaching in cannot alter a documented example for later builders" do
      example = described_class::Fixtures.for(:tags_create)["responses"]["200"]["tag"]
      expect(example).to be_frozen
      expect(example["name"]).to be_frozen
      expect(described_class::Fixtures.for(:tags_list)["responses"]["200"]["tags"]).to be_frozen
      expect { example["name"] = "CORRUPT" }.to raise_error(FrozenError)
      expect { example["name"] << "!" }.to raise_error(FrozenError)
      expect(described_class.tag_json["tag"]["name"]).not_to eq("CORRUPT")
    end

    it "still hands out unfrozen, mutable bodies from every builder" do
      body = described_class.tag_json
      expect(body).not_to be_frozen
      expect(body["tag"]).not_to be_frozen
      expect { body["tag"]["name"] << "!" }.not_to raise_error
      rows = described_class.list_json(:tags_list, 2)["tags"]
      expect { rows[0]["name"] << "!" }.not_to raise_error
    end

    it "returns nothing frozen and nothing aliased to a caller's value from any builder" do
      cursor = +"E"
      message = +"bad"
      outputs = {
        pagination_json: described_class.pagination_json(end_cursor: cursor),
        list_json: described_class.list_json(:tags_list, 1, end_cursor: cursor),
        error_json: described_class.error_json(message, "x"),
        response: described_class.response(:tags_create, name: cursor),
        attributes: described_class.attributes(:tags_create, name: cursor)
      }
      cursor << "!"
      message << "!"

      outputs.each do |builder, output|
        frozen = []
        walk = lambda do |value|
          frozen << value if value.frozen? && !value.is_a?(Numeric) && !value.nil? && ![true, false].include?(value)
          case value
          when Hash then value.each_value(&walk)
          when Array then value.each(&walk)
          end
        end
        walk.call(output)
        expect(frozen).to be_empty, "#{builder}: frozen values #{frozen.inspect}"
      end
      expect(outputs[:pagination_json]["end_cursor"]).to eq("E")
      expect(outputs[:list_json]["pagination"]["end_cursor"]).to eq("E")
      expect(outputs[:error_json]["errors"]).to eq(%w[bad x])
      expect(outputs[:response]["tag"]["name"]).to eq("E")
    end
  end

  it "loads standalone in a clean process, without kit-rb, WebMock or anything preloaded" do
    output = IO.popen([RbConfig.ruby, "--disable-gems", "-Ilib", "-e",
                       'require "kit/testing"; print Kit::Testing.tag_json(name: "vip")["tag"]["name"]'], &:read)
    expect(output).to eq("vip")
  end

  it "is not loaded by require \"kit-rb\" alone" do
    output = IO.popen([RbConfig.ruby, "-Ilib", "-e", 'require "kit-rb"; print defined?(Kit::Testing).inspect'], &:read)
    expect(output).to eq("nil")
  end
end
