# frozen_string_literal: true

require_relative "../support/smoke"

# End-to-end lifecycle against the real API: create -> update -> list -> delete a
# custom field, asserting each step and cleaning up after itself. It mutates the
# live account, so it is opt-in: it runs only when KIT_E2E=1 and a key is present
# (env or .env). custom_fields are the safest lifecycle — they send nothing and
# support create/update/delete — so the account is left exactly as it started.
RSpec.describe "Custom field lifecycle (e2e)", :e2e do
  before(:all) do
    skip "set KIT_E2E=1 with a live KIT_API_KEY to run e2e" unless ENV["KIT_E2E"] == "1"

    @key = Kit::Smoke.api_key
    skip "no KIT_API_KEY available" if @key.nil? || @key.empty?

    VCR.turn_off!
    WebMock.allow_net_connect!
    @client = Kit::Client.new(api_key: @key)
    @label = "kit-rb e2e #{Time.now.to_i}"
    @created_id = nil
  end

  after(:all) do
    @client.custom_fields.delete(@created_id) if @created_id
  rescue Kit::NotFoundError
    # already deleted by the test itself
  ensure
    WebMock.disable_net_connect!
    VCR.turn_on!
  end

  it "creates, updates, lists, and deletes a custom field" do
    created = @client.custom_fields.create(label: @label)
    expect(created).to be_a(Kit::Objects::CustomField)
    expect(created.id).to be_a(Integer)
    @created_id = created.id

    renamed = @client.custom_fields.update(@created_id, label: "#{@label} renamed")
    expect(renamed.label).to eq("#{@label} renamed")

    ids = @client.custom_fields.list.auto_paging_each.map(&:id)
    expect(ids).to include(@created_id)

    expect(@client.custom_fields.delete(@created_id)).to be_nil
    @created_id = nil

    remaining = @client.custom_fields.list.auto_paging_each.map(&:label)
    expect(remaining).not_to include("#{@label} renamed")
  end
end
