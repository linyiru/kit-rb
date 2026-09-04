# frozen_string_literal: true

RSpec.describe Kit::Resources::Posts do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def post(id:, title: "Hello World")
    { "id" => id, "publication_id" => id + 500, "created_at" => "2026-01-01T00:00:00Z",
      "title" => title, "slug" => "hello-world", "description" => nil, "meta_description" => nil,
      "status" => "published", "published_at" => "2026-01-02T00:00:00Z", "sent_at" => nil,
      "thumbnail_alt" => nil, "thumbnail_url" => nil, "is_paid" => false,
      "public_url" => "https://example.test/p/#{id}" }
  end

  describe "#list" do
    it "returns a Collection of typed Post" do
      body = { "posts" => [post(id: 1), post(id: 2, title: "Second")],
               "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                                 "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
      stub_kit(:get, "/v4/posts", body: body)
      list = client.posts.list
      expect(list.first).to be_a(Kit::Objects::Post)
      expect(list.map(&:title)).to eq(["Hello World", "Second"])
    end
  end

  describe "#get" do
    it "fetches one post" do
      stub_kit(:get, "/v4/posts/7", body: { "post" => post(id: 7) })
      expect(client.posts.get(7).slug).to eq("hello-world")
    end
  end
end
