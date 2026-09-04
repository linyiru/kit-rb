# frozen_string_literal: true

RSpec.describe Kit::Resources::Segments do
  let(:client) { Kit::Client.new(api_key: "secret") }

  describe "#list" do
    it "returns a Collection of typed Segment" do
      body = { "segments" => [{ "id" => 1, "name" => "Engaged", "created_at" => "2026-01-01T00:00:00Z" }],
               "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                                 "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
      stub_kit(:get, "/v4/segments", body: body)
      list = client.segments.list
      expect(list.first).to be_a(Kit::Objects::Segment)
      expect(list.first.name).to eq("Engaged")
    end
  end
end
