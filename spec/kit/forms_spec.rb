# frozen_string_literal: true

RSpec.describe Kit::Resources::Forms do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def form(id:, name: "Newsletter")
    { "id" => id, "name" => name, "created_at" => "2026-01-01T00:00:00Z",
      "type" => "embed", "format" => nil, "embed_js" => "https://x/#{id}.js",
      "embed_url" => "https://x/#{id}", "archived" => false, "uid" => "u#{id}" }
  end

  def sub(id:) = { "id" => id, "email_address" => "s#{id}@x.com", "state" => "active" }

  def page(key, items)
    { key => items,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed Form" do
      stub_kit(:get, "/v4/forms", body: page("forms", [form(id: 1), form(id: 2)]))
      list = client.forms.list
      expect(list.first).to be_a(Kit::Objects::Form)
      expect(list.map(&:uid)).to eq(%w[u1 u2])
    end
  end

  describe "#subscribers" do
    it "returns a Collection of Subscriber for the form" do
      stub_kit(:get, "/v4/forms/7/subscribers", body: page("subscribers", [sub(id: 1)]))
      expect(client.forms.subscribers(7).first).to be_a(Kit::Objects::Subscriber)
    end
  end

  describe "#add_subscriber" do
    it "posts referrer to the by-id endpoint and returns the Subscriber" do
      stub = stub_request(:post, "https://api.kit.com/v4/forms/7/subscribers/42")
             .with(body: { "referrer" => "https://ref" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("subscriber" => sub(id: 42)))
      expect(client.forms.add_subscriber(7, 42, referrer: "https://ref")).to be_a(Kit::Objects::Subscriber)
      expect(stub).to have_been_requested
    end
  end

  describe "#add_subscriber_by_email" do
    it "posts the email to the by-email endpoint, dropping a nil referrer" do
      stub = stub_request(:post, "https://api.kit.com/v4/forms/7/subscribers")
             .with(body: { "email_address" => "new@x.com" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("subscriber" => sub(id: 99)))
      expect(client.forms.add_subscriber_by_email(7, email_address: "new@x.com")).to be_a(Kit::Objects::Subscriber)
      expect(stub).to have_been_requested
    end
  end
end
