# frozen_string_literal: true

RSpec.describe Kit::Resources::Purchases do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def product(name: "Book")
    { "name" => name, "pid" => "P1", "lid" => "L1", "sku" => "SKU1",
      "unit_price" => 9.0, "quantity" => 1 }
  end

  def purchase(id:, txn: "t-#{id}")
    { "id" => id, "transaction_id" => txn, "subscriber_id" => 42, "status" => "paid",
      "email_address" => "buyer@x.com", "currency" => "USD",
      "transaction_time" => "2026-01-01T00:00:00Z", "subtotal" => 9.0, "discount" => 0.0,
      "tax" => 0.0, "total" => 9.0, "products" => [product], "source" => "api" }
  end

  def page(purchases)
    { "purchases" => purchases,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed Purchase" do
      stub_kit(:get, "/v4/purchases", body: page([purchase(id: 1)]))
      list = client.purchases.list
      expect(list.first).to be_a(Kit::Objects::Purchase)
      expect(list.first.total).to eq(9.0)
    end
  end

  describe "#get" do
    it "fetches one purchase" do
      stub_kit(:get, "/v4/purchases/5", body: { "purchase" => purchase(id: 5) })
      expect(client.purchases.get(5).transaction_id).to eq("t-5")
    end
  end

  describe "#create" do
    it "wraps the attributes under a purchase key and returns a Purchase" do
      attrs = { "email_address" => "buyer@x.com", "transaction_id" => "t-9",
                "status" => "paid", "currency" => "USD", "total" => 9.0,
                "products" => [product] }
      stub = stub_request(:post, "https://api.kit.com/v4/purchases")
             .with(body: { "purchase" => attrs })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("purchase" => purchase(id: 9, txn: "t-9")))
      result = client.purchases.create(**attrs.transform_keys(&:to_sym))
      expect(result).to be_a(Kit::Objects::Purchase)
      expect(stub).to have_been_requested
    end
  end
end
