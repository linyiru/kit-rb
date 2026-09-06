# frozen_string_literal: true

RSpec.describe Kit::Resources::Subscribers do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def subscriber(id:, email: "s#{id}@example.com", state: "active")
    { "id" => id, "email_address" => email, "state" => state,
      "first_name" => nil, "created_at" => "2026-01-01T00:00:00Z",
      "canceled_at" => nil, "location" => nil, "fields" => {} }
  end

  def page(subs, has_next:, end_cursor: "END")
    {
      "subscribers" => subs,
      "pagination" => { "has_previous_page" => false, "has_next_page" => has_next,
                        "start_cursor" => "S", "end_cursor" => end_cursor, "per_page" => 2 }
    }
  end

  describe "#list" do
    it "returns a Collection of typed Subscriber for the current page" do
      stub_kit(:get, "/v4/subscribers", body: page([subscriber(id: 1), subscriber(id: 2)], has_next: false))
      collection = client.subscribers.list
      expect(collection).to be_a(Kit::Collection)
      expect(collection.map(&:email_address)).to eq(%w[s1@example.com s2@example.com])
      expect(collection.first).to be_a(Kit::Objects::Subscriber)
    end

    it "passes filters as query params" do
      stub = stub_request(:get, "https://api.kit.com/v4/subscribers")
             .with(query: { "status" => "active", "per_page" => "2" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate(page([subscriber(id: 1)], has_next: false)))
      client.subscribers.list(status: "active", per_page: 2).to_a
      expect(stub).to have_been_requested
    end

    it "auto_paging_each follows end_cursor across pages" do
      # WebMock picks the most-recently-defined matching stub, so the after=C1
      # request hits the second stub; the first (no query) hits page one.
      stub_request(:get, "https://api.kit.com/v4/subscribers")
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate(page([subscriber(id: 1)], has_next: true, end_cursor: "C1")))
      stub_request(:get, "https://api.kit.com/v4/subscribers")
        .with(query: { "after" => "C1" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate(page([subscriber(id: 2)], has_next: false)))

      ids = client.subscribers.list.auto_paging_each.map(&:id)
      expect(ids).to eq([1, 2])
    end

    it "sends include_total_count on the first page only and surfaces total_count" do
      first = page([subscriber(id: 1)], has_next: true, end_cursor: "C1")
      first["pagination"]["total_count"] = 2
      stub_request(:get, "https://api.kit.com/v4/subscribers")
        .with(query: { "include_total_count" => "true" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: JSON.generate(first))
      second = stub_request(:get, "https://api.kit.com/v4/subscribers")
               .with(query: { "after" => "C1" })
               .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                          body: JSON.generate(page([subscriber(id: 2)], has_next: false)))

      collection = client.subscribers.list(include_total_count: true)
      expect(collection.total_count).to eq(2)
      expect(collection.auto_paging_each.map(&:id)).to eq([1, 2])
      expect(second).to have_been_requested
    end
  end

  describe "#get" do
    it "fetches one subscriber" do
      stub_kit(:get, "/v4/subscribers/42", body: { "subscriber" => subscriber(id: 42) })
      expect(client.subscribers.get(42).id).to eq(42)
    end
  end

  describe "#create" do
    it "posts required and optional fields, dropping nils" do
      stub = stub_request(:post, "https://api.kit.com/v4/subscribers")
             .with(body: { "email_address" => "new@example.com", "first_name" => "Ada" })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("subscriber" => subscriber(id: 7, email: "new@example.com")))
      sub = client.subscribers.create(email_address: "new@example.com", first_name: "Ada")
      expect(sub).to be_a(Kit::Objects::Subscriber)
      expect(stub).to have_been_requested
    end
  end

  describe "#update" do
    it "puts the changed fields" do
      stub = stub_request(:put, "https://api.kit.com/v4/subscribers/7")
             .with(body: { "first_name" => "Grace" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("subscriber" => subscriber(id: 7)))
      client.subscribers.update(7, first_name: "Grace")
      expect(stub).to have_been_requested
    end
  end

  describe "#unsubscribe" do
    it "posts to the unsubscribe endpoint and returns nil on the spec's 204 no-content" do
      stub = stub_kit(:post, "/v4/subscribers/7/unsubscribe", status: 204, body: "")
      expect(client.subscribers.unsubscribe(7)).to be_nil
      expect(stub).to have_been_requested
    end

    it "returns the subscriber when the API echoes one back" do
      stub_kit(:post, "/v4/subscribers/7/unsubscribe",
               body: { "subscriber" => subscriber(id: 7, state: "cancelled") })
      expect(client.subscribers.unsubscribe(7).state).to eq("cancelled")
    end
  end
end
