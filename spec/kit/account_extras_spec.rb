# frozen_string_literal: true

RSpec.describe "Kit::Resources::Account extras" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  describe "#colors / #update_colors" do
    it "reads the palette" do
      stub_kit(:get, "/v4/account/colors", body: { "colors" => %w[#fff #000] })
      expect(client.account.colors).to eq(%w[#fff #000])
    end

    it "replaces the palette and returns the saved colors" do
      stub = stub_request(:put, "https://api.kit.com/v4/account/colors")
             .with(body: { "colors" => %w[#123456] })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("colors" => %w[#123456]))
      expect(client.account.update_colors(%w[#123456])).to eq(%w[#123456])
      expect(stub).to have_been_requested
    end
  end

  describe "#creator_profile" do
    it "returns a typed CreatorProfile" do
      stub_kit(:get, "/v4/account/creator_profile",
               body: { "profile" => { "name" => "Ada", "byline" => "Writer", "bio" => "Hi",
                                      "image_url" => nil, "profile_url" => "https://x/ada" } })
      profile = client.account.creator_profile
      expect(profile).to be_a(Kit::Objects::CreatorProfile)
      expect(profile.name).to eq("Ada")
    end
  end

  describe "#email_stats" do
    it "returns typed EmailStats" do
      stub_kit(:get, "/v4/account/email_stats",
               body: { "stats" => { "sent" => 5, "open_rate" => 0.4, "email_stats_mode" => "all" } })
      stats = client.account.email_stats
      expect(stats).to be_a(Kit::Objects::EmailStats)
      expect(stats.sent).to eq(5)
      expect(stats.open_rate).to eq(0.4)
    end
  end

  describe "#growth_stats" do
    it "passes starting/ending and returns typed GrowthStats" do
      stub = stub_request(:get, "https://api.kit.com/v4/account/growth_stats")
             .with(query: { "starting" => "2026-01-01" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("stats" => { "subscribers" => 100, "new_subscribers" => 5 }))
      stats = client.account.growth_stats(starting: "2026-01-01")
      expect(stats).to be_a(Kit::Objects::GrowthStats)
      expect(stats.subscribers).to eq(100)
      expect(stats.new_subscribers).to eq(5)
      expect(stub).to have_been_requested
    end
  end
end
