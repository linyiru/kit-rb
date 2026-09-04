# frozen_string_literal: true

RSpec.describe "Kit::Resources::Subscribers extras" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def sub(id:) = { "id" => id, "email_address" => "s#{id}@x.com", "state" => "active" }

  def page(key, items)
    { key => items,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#filter" do
    it "POSTs to /filter and returns a Collection of Subscriber" do
      stub = stub_request(:post, "https://api.kit.com/v4/subscribers/filter")
             .with(query: { "status" => "active" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate(page("subscribers", [sub(id: 1)])))
      list = client.subscribers.filter(status: "active")
      expect(list.first).to be_a(Kit::Objects::Subscriber)
      expect(stub).to have_been_requested
    end
  end

  describe "#tags" do
    it "returns a Collection of the subscriber's Tags" do
      stub_kit(:get, "/v4/subscribers/42/tags",
               body: page("tags", [{ "id" => 3, "name" => "vip", "created_at" => "2026-01-01T00:00:00Z",
                                     "subscriber_count" => 1 }]))
      list = client.subscribers.tags(42)
      expect(list.first).to be_a(Kit::Objects::Tag)
      expect(list.first.name).to eq("vip")
    end
  end

  describe "#stats" do
    it "returns the raw subscriber stats hash" do
      stub_kit(:get, "/v4/subscribers/42/stats",
               body: { "subscriber" => { "id" => 42, "stats" => { "sent" => 10, "opened" => 4 } } })
      stats = client.subscribers.stats(42)
      expect(stats["stats"]).to eq("sent" => 10, "opened" => 4)
    end
  end

  describe "#set_location" do
    it "POSTs the location and returns the Subscriber" do
      location = { "country_code" => "US", "city" => "Austin" }
      stub = stub_request(:post, "https://api.kit.com/v4/subscribers/42/location")
             .with(body: { "location" => location })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("subscriber" => sub(id: 42)))
      expect(client.subscribers.set_location(42, location: location)).to be_a(Kit::Objects::Subscriber)
      expect(stub).to have_been_requested
    end
  end

  describe "#remove_location" do
    it "deletes the location and returns nil" do
      stub = stub_kit(:delete, "/v4/subscribers/42/location", status: 204, body: "")
      expect(client.subscribers.remove_location(42)).to be_nil
      expect(stub).to have_been_requested
    end
  end
end
