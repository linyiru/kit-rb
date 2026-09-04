# frozen_string_literal: true

RSpec.describe Kit::Resources::CustomFields do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def field(id:, label: "Birthday", key: "birthday", name: "ck_field_1_birthday")
    { "id" => id, "name" => name, "key" => key, "label" => label }
  end

  def page(fields, has_next: false)
    { "custom_fields" => fields,
      "pagination" => { "has_previous_page" => false, "has_next_page" => has_next,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#list" do
    it "returns a Collection of typed CustomField" do
      stub_kit(:get, "/v4/custom_fields", body: page([field(id: 1), field(id: 2)]))
      list = client.custom_fields.list
      expect(list).to be_a(Kit::Collection)
      expect(list.first).to be_a(Kit::Objects::CustomField)
      expect(list.map(&:key)).to eq(%w[birthday birthday])
    end
  end

  describe "#create" do
    it "posts the label and returns a CustomField" do
      stub = stub_request(:post, "https://api.kit.com/v4/custom_fields")
             .with(body: { "label" => "Birthday" })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("custom_field" => field(id: 9)))
      expect(client.custom_fields.create(label: "Birthday")).to be_a(Kit::Objects::CustomField)
      expect(stub).to have_been_requested
    end
  end

  describe "#update" do
    it "puts the new label and returns the CustomField" do
      stub_kit(:put, "/v4/custom_fields/9", body: { "custom_field" => field(id: 9, label: "Renamed") })
      expect(client.custom_fields.update(9, label: "Renamed").label).to eq("Renamed")
    end
  end

  describe "#delete" do
    it "deletes the field and returns nil" do
      stub = stub_kit(:delete, "/v4/custom_fields/9", status: 204, body: "")
      expect(client.custom_fields.delete(9)).to be_nil
      expect(stub).to have_been_requested
    end
  end
end
