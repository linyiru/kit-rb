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
