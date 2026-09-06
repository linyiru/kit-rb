# frozen_string_literal: true

RSpec.describe Kit::Resources::Broadcasts do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def broadcast(id:, subject: "Launch")
    { "id" => id, "publication_id" => id + 1000, "created_at" => "2026-01-01T00:00:00Z",
      "subject" => subject, "preview_text" => nil, "description" => nil, "content" => nil,
      "public" => false, "published_at" => nil, "send_at" => nil, "thumbnail_alt" => nil,
      "thumbnail_url" => nil, "public_url" => nil, "email_address" => nil,
      "email_template" => { "id" => 1, "name" => "Default" }, "subscriber_filter" => [],
      "status" => "draft" }
  end

  def page(broadcasts)
    { "broadcasts" => broadcasts,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed Broadcast" do
      stub_kit(:get, "/v4/broadcasts", body: page([broadcast(id: 1), broadcast(id: 2)]))
      list = client.broadcasts.list
      expect(list.first).to be_a(Kit::Objects::Broadcast)
      expect(list.map(&:subject)).to eq(%w[Launch Launch])
    end
  end

  describe "#get" do
    it "fetches one broadcast" do
      stub_kit(:get, "/v4/broadcasts/5", body: { "broadcast" => broadcast(id: 5) })
      expect(client.broadcasts.get(5).id).to eq(5)
    end
  end

  describe "#create" do
    it "posts attributes and returns a Broadcast" do
      stub = stub_request(:post, "https://api.kit.com/v4/broadcasts")
             .with(body: { "subject" => "Hello", "public" => true })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("broadcast" => broadcast(id: 9, subject: "Hello")))
      expect(client.broadcasts.create(subject: "Hello", public: true)).to be_a(Kit::Objects::Broadcast)
      expect(stub).to have_been_requested
    end

    it "keeps false values and drops only the fields not passed" do
      stub = stub_request(:post, "https://api.kit.com/v4/broadcasts")
             .with(body: { "subject" => "Hi", "public" => false, "send_at" => nil })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("broadcast" => broadcast(id: 1)))
      client.broadcasts.create(subject: "Hi", public: false, send_at: nil)
      expect(stub).to have_been_requested
    end
  end

  describe "#update" do
    it "puts changed attributes" do
      stub_kit(:put, "/v4/broadcasts/9", body: { "broadcast" => broadcast(id: 9, subject: "Edited") })
      expect(client.broadcasts.update(9, subject: "Edited").subject).to eq("Edited")
    end
  end

  describe "#delete" do
    it "deletes the broadcast and returns nil" do
      stub = stub_kit(:delete, "/v4/broadcasts/9", status: 204, body: "")
      expect(client.broadcasts.delete(9)).to be_nil
      expect(stub).to have_been_requested
    end
  end
end
