# frozen_string_literal: true

# Contract tests: pin each list resource against the vendored OpenAPI spec so a
# resource that reads the wrong envelope key fails automatically — the class of
# bug RuboCop and Steep cannot see, because the HTTP response is untyped.
#
# To register a new list resource, add one row to LISTS. The two shared examples
# then check it against the spec for free: the key it reads must be the key the
# spec declares. `stub_body` deliberately keys the stubbed response off the
# SPEC's envelope (not the row), so if the code reads a different key it raises
# KeyError in Base#collection and the example fails.
# The registry of implemented list resources. One row per list endpoint:
#   spec_path:    the spec's templated path, looked up in the OpenAPI document.
#   runtime_path: the concrete path the invocation actually requests.
#   invoke:       calls the resource method under test, returning a Collection.
#   klass:        the object each element is expected to become.
module ContractRegistry
  LISTS = [
    { spec_path: "/v4/subscribers", runtime_path: "/v4/subscribers",
      invoke: ->(c) { c.subscribers.list }, klass: Kit::Objects::Subscriber },
    { spec_path: "/v4/tags", runtime_path: "/v4/tags",
      invoke: ->(c) { c.tags.list }, klass: Kit::Objects::Tag },
    { spec_path: "/v4/tags/{tag_id}/subscribers", runtime_path: "/v4/tags/9/subscribers",
      invoke: ->(c) { c.tags.subscribers(9) }, klass: Kit::Objects::Subscriber },
    { spec_path: "/v4/custom_fields", runtime_path: "/v4/custom_fields",
      invoke: ->(c) { c.custom_fields.list }, klass: Kit::Objects::CustomField },
    { spec_path: "/v4/forms", runtime_path: "/v4/forms",
      invoke: ->(c) { c.forms.list }, klass: Kit::Objects::Form },
    { spec_path: "/v4/forms/{form_id}/subscribers", runtime_path: "/v4/forms/7/subscribers",
      invoke: ->(c) { c.forms.subscribers(7) }, klass: Kit::Objects::Subscriber }
  ].freeze
end

RSpec.describe "OpenAPI list-envelope contract" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def stub_body(envelope)
    { envelope => [{}],
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => nil, "end_cursor" => nil, "per_page" => 2 } }
  end

  ContractRegistry::LISTS.each do |row|
    context row[:spec_path] do
      let(:envelope) { OpenAPIContract.envelope_for(row[:spec_path]) }

      it "is a cursor-paginated list endpoint in the spec" do
        expect(envelope).not_to be_nil,
                                "spec declares no paginated GET for #{row[:spec_path]}"
      end

      it "reads the envelope key the spec declares" do
        stub_kit(:get, row[:runtime_path], body: stub_body(envelope))
        collection = row[:invoke].call(client)
        expect(collection).to be_a(Kit::Collection)
        expect(collection.first).to be_a(row[:klass])
      end
    end
  end

  it "registers only paths the spec knows as list endpoints" do
    registered = ContractRegistry::LISTS.map { |r| r[:spec_path] }
    expect(registered).to all(satisfy { |p| OpenAPIContract.list_endpoints.key?(p) })
  end
end
