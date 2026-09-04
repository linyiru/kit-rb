# frozen_string_literal: true

RSpec.describe Kit::Resources::Sequences do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def sequence(id:, name: "Welcome")
    { "id" => id, "name" => name, "hold" => false, "repeat" => false,
      "created_at" => "2026-01-01T00:00:00Z" }
  end

  def sub(id:) = { "id" => id, "email_address" => "s#{id}@x.com", "state" => "active" }

  def page(key, items)
    { key => items,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed Sequence" do
      stub_kit(:get, "/v4/sequences", body: page("sequences", [sequence(id: 1), sequence(id: 2)]))
      expect(client.sequences.list.map(&:name)).to eq(%w[Welcome Welcome])
      expect(client.sequences.list.first).to be_a(Kit::Objects::Sequence)
    end
  end

  describe "#get" do
    it "fetches one sequence" do
      stub_kit(:get, "/v4/sequences/5", body: { "sequence" => sequence(id: 5) })
      expect(client.sequences.get(5).id).to eq(5)
    end
  end

  describe "#create" do
    it "posts name and attributes, returning a Sequence" do
      stub = stub_request(:post, "https://api.kit.com/v4/sequences")
             .with(body: { "name" => "Onboarding", "active" => true })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("sequence" => sequence(id: 9, name: "Onboarding")))
      seq = client.sequences.create(name: "Onboarding", active: true)
      expect(seq).to be_a(Kit::Objects::Sequence)
      expect(stub).to have_been_requested
    end
  end

  describe "#update" do
    it "puts changed attributes" do
      stub_kit(:put, "/v4/sequences/9", body: { "sequence" => sequence(id: 9, name: "Renamed") })
      expect(client.sequences.update(9, name: "Renamed").name).to eq("Renamed")
    end
  end

  describe "#delete" do
    it "deletes the sequence and returns nil" do
      stub = stub_kit(:delete, "/v4/sequences/9", status: 204, body: "")
      expect(client.sequences.delete(9)).to be_nil
      expect(stub).to have_been_requested
    end
  end

  describe "#subscribers" do
    it "returns a Collection of Subscriber for the sequence" do
      stub_kit(:get, "/v4/sequences/5/subscribers", body: page("subscribers", [sub(id: 1)]))
      expect(client.sequences.subscribers(5).first).to be_a(Kit::Objects::Subscriber)
    end
  end

  describe "#add_subscriber / #add_subscriber_by_email" do
    it "adds an existing subscriber by id" do
      stub_kit(:post, "/v4/sequences/5/subscribers/42", body: { "subscriber" => sub(id: 42) })
      expect(client.sequences.add_subscriber(5, 42)).to be_a(Kit::Objects::Subscriber)
    end

    it "adds a subscriber by email" do
      stub = stub_request(:post, "https://api.kit.com/v4/sequences/5/subscribers")
             .with(body: { "email_address" => "new@x.com" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("subscriber" => sub(id: 99)))
      expect(client.sequences.add_subscriber_by_email(5, email_address: "new@x.com")).to be_a(Kit::Objects::Subscriber)
      expect(stub).to have_been_requested
    end
  end
end
