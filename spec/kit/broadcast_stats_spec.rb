# frozen_string_literal: true

RSpec.describe "Kit::Resources::Broadcasts stats and clicks" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  describe "#stats_list" do
    it "returns a Collection of raw per-broadcast stat hashes" do
      body = { "broadcasts" => [{ "id" => 1, "subject" => "A", "send_at" => nil,
                                  "stats" => { "recipients" => 10, "open_rate" => 0.5 } }],
               "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                                 "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
      stub_kit(:get, "/v4/broadcasts/stats", body: body)
      list = client.broadcasts.stats_list
      expect(list).to be_a(Kit::Collection)
      expect(list.first).to eq("id" => 1, "subject" => "A", "send_at" => nil,
                               "stats" => { "recipients" => 10, "open_rate" => 0.5 })
    end
  end

  describe "#stats" do
    it "returns the raw stats hash for one broadcast" do
      stub_kit(:get, "/v4/broadcasts/9/stats",
               body: { "broadcast" => { "id" => 9, "stats" => { "recipients" => 3 } } })
      expect(client.broadcasts.stats(9)).to eq("id" => 9, "stats" => { "recipients" => 3 })
    end
  end

  describe "#clicks" do
    it "returns the raw click report and passes pagination params" do
      stub = stub_request(:get, "https://api.kit.com/v4/broadcasts/9/clicks")
             .with(query: { "per_page" => "5" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("broadcast" => { "id" => 9,
                                                             "clicks" => [{ "url" => "https://x",
                                                                            "unique_clicks" => 2 }] },
                                            "pagination" => {}))
      report = client.broadcasts.clicks(9, per_page: 5)
      expect(report["clicks"].first["url"]).to eq("https://x")
      expect(stub).to have_been_requested
    end
  end
end
