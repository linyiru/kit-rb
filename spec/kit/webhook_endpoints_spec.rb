# frozen_string_literal: true

RSpec.describe Kit::Resources::WebhookEndpoints do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def endpoint(id:, url: "https://example.test/wh", name: "Prod")
    { "id" => id, "name" => name, "url" => url, "events" => %w[subscriber.subscriber_activate],
      "status" => "active", "source" => "api", "description" => "",
      "created_by_app" => nil, "created_at" => "2026-01-01T00:00:00Z",
      "previous_secret_expires_at" => nil }
  end

  def page(endpoints)
    { "webhook_endpoints" => endpoints,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed WebhookEndpoint" do
      stub_kit(:get, "/v4/webhook_endpoints", body: page([endpoint(id: 1)]))
      expect(client.webhook_endpoints.list.first).to be_a(Kit::Objects::WebhookEndpoint)
    end
  end

  describe "#get" do
    it "fetches one endpoint" do
      stub_kit(:get, "/v4/webhook_endpoints/5", body: { "webhook_endpoint" => endpoint(id: 5) })
      expect(client.webhook_endpoints.get(5).id).to eq(5)
    end
  end

  describe "#create" do
    it "posts url and events, returning an endpoint" do
      stub = stub_request(:post, "https://api.kit.com/v4/webhook_endpoints")
             .with(body: { "url" => "https://example.test/wh", "events" => %w[subscriber.subscriber_activate] })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("webhook_endpoint" => endpoint(id: 9)))
      result = client.webhook_endpoints.create(url: "https://example.test/wh",
                                               events: %w[subscriber.subscriber_activate])
      expect(result).to be_a(Kit::Objects::WebhookEndpoint)
      expect(stub).to have_been_requested
    end

    it "surfaces the one-time signing secret Kit returns on create" do
      created_body = { "webhook_endpoint" => endpoint(id: 9).merge("secret" => "whsec_abc123") }
      stub_kit(:post, "/v4/webhook_endpoints", status: 201, body: created_body)
      created = client.webhook_endpoints.create(url: "https://example.test/wh", events: %w[subscriber.created])
      expect(created.secret).to eq("whsec_abc123")
    end
  end

  it "reads back with a nil secret, since Kit never returns it again" do
    stub_kit(:get, "/v4/webhook_endpoints/9", body: { "webhook_endpoint" => endpoint(id: 9) })
    expect(client.webhook_endpoints.get(9).secret).to be_nil
  end

  describe "#delete" do
    it "deletes the endpoint and returns nil" do
      stub = stub_kit(:delete, "/v4/webhook_endpoints/9", status: 204, body: "")
      expect(client.webhook_endpoints.delete(9)).to be_nil
      expect(stub).to have_been_requested
    end
  end

  describe "#rotate_secret" do
    it "posts force and returns the endpoint" do
      stub = stub_request(:post, "https://api.kit.com/v4/webhook_endpoints/9/rotate_secret")
             .with(body: { "force" => true })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("webhook_endpoint" => endpoint(id: 9)))
      expect(client.webhook_endpoints.rotate_secret(9, force: true)).to be_a(Kit::Objects::WebhookEndpoint)
      expect(stub).to have_been_requested
    end

    it "surfaces the new signing secret" do
      stub_kit(:post, "/v4/webhook_endpoints/9/rotate_secret",
               body: { "webhook_endpoint" => endpoint(id: 9).merge("secret" => "whsec_rotated") })
      expect(client.webhook_endpoints.rotate_secret(9).secret).to eq("whsec_rotated")
    end
  end

  describe "#revoke_previous_secret" do
    it "posts to revoke and returns the endpoint" do
      stub_kit(:post, "/v4/webhook_endpoints/9/revoke_previous_secret",
               body: { "webhook_endpoint" => endpoint(id: 9) })
      expect(client.webhook_endpoints.revoke_previous_secret(9)).to be_a(Kit::Objects::WebhookEndpoint)
    end
  end
end
