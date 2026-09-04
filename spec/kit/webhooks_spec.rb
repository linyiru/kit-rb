# frozen_string_literal: true

RSpec.describe Kit::Resources::Webhooks do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def webhook(id:, url: "https://example.test/hook")
    { "id" => id, "account_id" => 100,
      "event" => { "name" => "subscriber.subscriber_activate", "tag_id" => nil, "form_id" => nil },
      "target_url" => url }
  end

  def page(webhooks)
    { "webhooks" => webhooks,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed Webhook" do
      stub_kit(:get, "/v4/webhooks", body: page([webhook(id: 1), webhook(id: 2)]))
      list = client.webhooks.list
      expect(list.first).to be_a(Kit::Objects::Webhook)
      expect(list.first.event["name"]).to eq("subscriber.subscriber_activate")
    end
  end

  describe "#create" do
    it "posts target_url and event, returning a Webhook" do
      event = { "name" => "subscriber.subscriber_activate" }
      stub = stub_request(:post, "https://api.kit.com/v4/webhooks")
             .with(body: { "target_url" => "https://example.test/hook", "event" => event })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("webhook" => webhook(id: 9)))
      result = client.webhooks.create(target_url: "https://example.test/hook", event: event)
      expect(result).to be_a(Kit::Objects::Webhook)
      expect(stub).to have_been_requested
    end
  end

  describe "#delete" do
    it "deletes the webhook and returns nil" do
      stub = stub_kit(:delete, "/v4/webhooks/9", status: 204, body: "")
      expect(client.webhooks.delete(9)).to be_nil
      expect(stub).to have_been_requested
    end
  end
end
