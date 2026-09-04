# frozen_string_literal: true

RSpec.describe Kit::Resources::Bulk do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def result(key, items)
    { key => items, "failures" => [] }
  end

  describe "#create_subscribers" do
    it "posts the subscribers array and returns the result hash" do
      subs = [{ "email_address" => "a@x.com" }, { "email_address" => "b@x.com" }]
      stub = stub_request(:post, "https://api.kit.com/v4/bulk/subscribers")
             .with(body: { "subscribers" => subs })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate(result("subscribers", [{ "id" => 1 }])))
      out = client.bulk.create_subscribers(subs)
      expect(out["subscribers"]).to eq([{ "id" => 1 }])
      expect(out["failures"]).to eq([])
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
  end

  describe "#create_custom_fields / #update_custom_field_values" do
    it "creates custom fields in bulk" do
      stub_kit(:post, "/v4/bulk/custom_fields", body: result("custom_fields", [{ "id" => 3 }]))
      expect(client.bulk.create_custom_fields([{ "label" => "A" }])["custom_fields"]).to eq([{ "id" => 3 }])
    end

    it "updates custom field values in bulk" do
      stub_kit(:post, "/v4/bulk/custom_fields/subscribers",
               body: result("custom_field_values", [{ "id" => 1 }]))
      out = client.bulk.update_custom_field_values([{ "id" => 1, "value" => "x" }])
      expect(out["custom_field_values"]).to eq([{ "id" => 1 }])
    end
  end

  describe "#add_subscribers_to_forms" do
    it "posts additions" do
      stub_kit(:post, "/v4/bulk/forms/subscribers", body: result("subscribers", [{ "id" => 5 }]))
      expect(client.bulk.add_subscribers_to_forms([{ "form_id" => 1, "subscriber_id" => 5 }])["subscribers"])
        .to eq([{ "id" => 5 }])
    end
  end

  describe "tag operations" do
    it "creates tags in bulk" do
      stub_kit(:post, "/v4/bulk/tags", body: result("tags", [{ "id" => 7 }]))
      expect(client.bulk.create_tags([{ "name" => "vip" }])["tags"]).to eq([{ "id" => 7 }])
    end

    it "deletes tags in bulk (DELETE with a body)" do
      stub = stub_request(:delete, "https://api.kit.com/v4/bulk/tags")
             .with(body: { "tags" => [7] })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("failures" => []))
      expect(client.bulk.delete_tags([7])["failures"]).to eq([])
      expect(stub).to have_been_requested
    end

    it "tags subscribers in bulk" do
      stub_kit(:post, "/v4/bulk/tags/subscribers", body: result("subscribers", [{ "id" => 9 }]))
      out = client.bulk.tag_subscribers([{ "tag_id" => 1, "subscriber_id" => 9 }])
      expect(out["subscribers"]).to eq([{ "id" => 9 }])
    end

    it "removes tag/subscriber pairs in bulk (DELETE with a body)" do
      stub = stub_request(:delete, "https://api.kit.com/v4/bulk/tags/subscribers")
             .with(body: { "taggings" => [{ "tag_id" => 1, "subscriber_id" => 9 }] })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("failures" => []))
      client.bulk.remove_tag_subscribers([{ "tag_id" => 1, "subscriber_id" => 9 }])
      expect(stub).to have_been_requested
    end
  end
end
