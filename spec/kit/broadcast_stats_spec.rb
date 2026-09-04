# frozen_string_literal: true

RSpec.describe "Kit::Resources::Broadcasts stats and clicks" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def metrics
    { "recipients" => 10, "open_rate" => 0.5, "emails_opened" => 5, "click_rate" => 0.2,
      "unsubscribe_rate" => 0.0, "unsubscribes" => 0, "total_clicks" => 3,
      "show_total_clicks" => true, "status" => "completed", "progress" => 100.0,
      "open_tracking_disabled" => false, "click_tracking_disabled" => false }
  end

  describe "#stats_list" do
    it "returns a Collection of typed BroadcastStats, flattening the nested stats" do
      body = { "broadcasts" => [{ "id" => 1, "subject" => "A", "send_at" => nil, "stats" => metrics }],
               "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                                 "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
      stub_kit(:get, "/v4/broadcasts/stats", body: body)
      stat = client.broadcasts.stats_list.first
      expect(stat).to be_a(Kit::Objects::BroadcastStats)
      expect(stat.id).to eq(1)
      expect(stat.subject).to eq("A")
      expect(stat.recipients).to eq(10)
      expect(stat.open_rate).to eq(0.5)
    end
  end

  describe "#stats" do
    it "returns typed BroadcastStats for one broadcast" do
      stub_kit(:get, "/v4/broadcasts/9/stats", body: { "broadcast" => { "id" => 9, "stats" => metrics } })
      stat = client.broadcasts.stats(9)
      expect(stat).to be_a(Kit::Objects::BroadcastStats)
      expect(stat.id).to eq(9)
      expect(stat.total_clicks).to eq(3)
      expect(stat.subject).to be_nil
    end
  end

  describe "#clicks" do
    it "returns a Collection of typed BroadcastClick and passes pagination params" do
      stub = stub_request(:get, "https://api.kit.com/v4/broadcasts/9/clicks")
             .with(query: { "per_page" => "5" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate(
                          "broadcast" => { "id" => 9,
                                           "clicks" => [{ "id" => 1, "url" => "https://x",
                                                          "unique_clicks" => 2, "click_to_delivery_rate" => 0.1,
                                                          "click_to_open_rate" => 0.4 }] },
                          "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                                            "start_cursor" => "S", "end_cursor" => "E", "per_page" => 5 }
                        ))
      clicks = client.broadcasts.clicks(9, per_page: 5)
      expect(clicks).to be_a(Kit::Collection)
      expect(clicks.first).to be_a(Kit::Objects::BroadcastClick)
      expect(clicks.first.url).to eq("https://x")
      expect(clicks.first.unique_clicks).to eq(2)
      expect(stub).to have_been_requested
    end
  end
end
