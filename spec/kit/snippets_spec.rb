# frozen_string_literal: true

RSpec.describe Kit::Resources::Snippets do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def snippet(id:, name: "Signature", type: "inline")
    { "id" => id, "name" => name, "snippet_type" => type, "archived" => false,
      "key" => "signature", "created_at" => "2026-01-01T00:00:00Z",
      "updated_at" => "2026-01-01T00:00:00Z", "content" => "Best, Ada", "document" => nil }
  end

  def page(snippets)
    { "snippets" => snippets,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed Snippet" do
      stub_kit(:get, "/v4/snippets", body: page([snippet(id: 1)]))
      expect(client.snippets.list.first).to be_a(Kit::Objects::Snippet)
    end
  end

  describe "#get" do
    it "fetches one snippet" do
      stub_kit(:get, "/v4/snippets/3", body: { "snippet" => snippet(id: 3) })
      expect(client.snippets.get(3).key).to eq("signature")
    end
  end

  describe "#create" do
    it "posts attributes and returns a Snippet" do
      stub = stub_request(:post, "https://api.kit.com/v4/snippets")
             .with(body: { "name" => "Sig", "snippet_type" => "inline", "content" => "Hi" })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("snippet" => snippet(id: 9, name: "Sig")))
      result = client.snippets.create(name: "Sig", snippet_type: "inline", content: "Hi")
      expect(result).to be_a(Kit::Objects::Snippet)
      expect(stub).to have_been_requested
    end
  end

  describe "#update" do
    it "puts changed attributes" do
      stub_kit(:put, "/v4/snippets/9", body: { "snippet" => snippet(id: 9, name: "Renamed") })
      expect(client.snippets.update(9, name: "Renamed").name).to eq("Renamed")
    end
  end
end
