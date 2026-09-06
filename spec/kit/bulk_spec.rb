# frozen_string_literal: true

RSpec.describe Kit::Resources::Bulk do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def result(key, items, failures: [])
    { key => items, "failures" => failures }
  end

  describe "#create_subscribers" do
    it "posts the subscribers array and returns a typed BulkResult" do
      subs = [{ "email_address" => "a@x.com" }, { "email_address" => "b@x.com" }]
      stub = stub_request(:post, "https://api.kit.com/v4/bulk/subscribers")
             .with(body: { "subscribers" => subs })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate(result("subscribers", [{ "id" => 1 }])))
      out = client.bulk.create_subscribers(subs)
      expect(out).to be_a(Kit::Objects::BulkResult)
      expect(out.items).to eq([{ "id" => 1 }])
      expect(out.failures).to eq([])
      expect(out).to be_success
      expect(out).not_to be_async
      expect(stub).to have_been_requested
    end

    it "includes callback_url when given" do
      stub = stub_request(:post, "https://api.kit.com/v4/bulk/subscribers")
             .with(body: { "subscribers" => [], "callback_url" => "https://cb" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate(result("subscribers", [])))
      client.bulk.create_subscribers([], callback_url: "https://cb")
      expect(stub).to have_been_requested
    end

    it "reports a queued batch (202, empty body) as async" do
      stub_kit(:post, "/v4/bulk/subscribers", status: 202, body: "")
      out = client.bulk.create_subscribers([])
      expect(out).to be_async
      expect(out).not_to be_success
      expect(out.items).to eq([])
      expect(out.failures).to eq([])
    end

    it "types each failure with the echoed item and its errors" do
      failures = [{ "subscriber" => { "email_address" => "bad", "state" => "active" },
                    "errors" => ["Email address is invalid"] }]
      stub_kit(:post, "/v4/bulk/subscribers", body: result("subscribers", [], failures: failures))
      out = client.bulk.create_subscribers([{ "email_address" => "bad" }])
      expect(out).not_to be_success
      failure = out.failures.first
      expect(failure).to be_a(Kit::Objects::BulkFailure)
      expect(failure.item).to eq("email_address" => "bad", "state" => "active")
      expect(failure.errors).to eq(["Email address is invalid"])
    end
  end

  describe "#create_custom_fields / #update_custom_field_values" do
    it "creates custom fields in bulk" do
      stub_kit(:post, "/v4/bulk/custom_fields", body: result("custom_fields", [{ "id" => 3 }]))
      expect(client.bulk.create_custom_fields([{ "label" => "A" }]).items).to eq([{ "id" => 3 }])
    end

    it "updates custom field values in bulk" do
      stub_kit(:post, "/v4/bulk/custom_fields/subscribers",
               body: result("custom_field_values", [{ "id" => 1 }]))
      out = client.bulk.update_custom_field_values([{ "id" => 1, "value" => "x" }])
      expect(out.items).to eq([{ "id" => 1 }])
    end
  end

  describe "#add_subscribers_to_forms" do
    it "posts additions" do
      stub_kit(:post, "/v4/bulk/forms/subscribers", body: result("subscribers", [{ "id" => 5 }]))
      expect(client.bulk.add_subscribers_to_forms([{ "form_id" => 1, "subscriber_id" => 5 }]).items)
        .to eq([{ "id" => 5 }])
    end
  end

  describe "tag operations" do
    it "creates tags in bulk" do
      stub_kit(:post, "/v4/bulk/tags", body: result("tags", [{ "id" => 7 }]))
      expect(client.bulk.create_tags([{ "name" => "vip" }]).items).to eq([{ "id" => 7 }])
    end

    it "deletes tags in bulk (DELETE with a body), returning failures only" do
      stub = stub_request(:delete, "https://api.kit.com/v4/bulk/tags")
             .with(body: { "tags" => [7] })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("failures" => []))
      out = client.bulk.delete_tags([7])
      expect(out.items).to eq([])
      expect(out).to be_success
      expect(stub).to have_been_requested
    end

    it "tags subscribers in bulk" do
      stub_kit(:post, "/v4/bulk/tags/subscribers", body: result("subscribers", [{ "id" => 9 }]))
      out = client.bulk.tag_subscribers([{ "tag_id" => 1, "subscriber_id" => 9 }])
      expect(out.items).to eq([{ "id" => 9 }])
    end

    it "removes tag/subscriber pairs in bulk (DELETE with a body)" do
      stub = stub_request(:delete, "https://api.kit.com/v4/bulk/tags/subscribers")
             .with(body: { "taggings" => [{ "tag_id" => 1, "subscriber_id" => 9 }] })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("failures" => []))
      expect(client.bulk.remove_tag_subscribers([{ "tag_id" => 1, "subscriber_id" => 9 }])).to be_success
      expect(stub).to have_been_requested
    end
  end
end
