# frozen_string_literal: true

RSpec.describe Kit::Resources::EmailTemplates do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def template(id:, name: "Default", is_default: true)
    { "id" => id, "name" => name, "is_default" => is_default, "category" => "newsletter" }
  end

  describe "#list" do
    it "returns a Collection of typed EmailTemplate" do
      body = { "email_templates" => [template(id: 1), template(id: 2, name: "Promo", is_default: false)],
               "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                                 "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
      stub_kit(:get, "/v4/email_templates", body: body)
      list = client.email_templates.list
      expect(list.first).to be_a(Kit::Objects::EmailTemplate)
      expect(list.map(&:name)).to eq(%w[Default Promo])
    end
  end
end
