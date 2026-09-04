# frozen_string_literal: true

# Integration tests: real Kit API responses, recorded once into VCR cassettes
# (secrets scrubbed) and replayed in CI. Unit specs prove we send the right
# request and parse a hand-written body; these prove the *real* response still
# parses into our value objects — catching response-shape drift the mocks can't.
#
# Re-record by deleting spec/cassettes/integration and running with a live
# KIT_API_KEY in the environment.
RSpec.describe "Read endpoints (integration)" do
  let(:client) { Kit::Client.new(api_key: ENV.fetch("KIT_API_KEY", "test-key")) }

  # name => [invocation, the element/object class each result should yield]
  {
    "account" => [->(c) { c.account.get }, Kit::Objects::AccountInfo],
    "subscribers" => [->(c) { c.subscribers.list }, Kit::Objects::Subscriber],
    "tags" => [->(c) { c.tags.list }, Kit::Objects::Tag],
    "custom_fields" => [->(c) { c.custom_fields.list }, Kit::Objects::CustomField],
    "forms" => [->(c) { c.forms.list }, Kit::Objects::Form],
    "sequences" => [->(c) { c.sequences.list }, Kit::Objects::Sequence],
    "broadcasts" => [->(c) { c.broadcasts.list }, Kit::Objects::Broadcast],
    "email_templates" => [->(c) { c.email_templates.list }, Kit::Objects::EmailTemplate],
    "segments" => [->(c) { c.segments.list }, Kit::Objects::Segment],
    "posts" => [->(c) { c.posts.list }, Kit::Objects::Post],
    "snippets" => [->(c) { c.snippets.list }, Kit::Objects::Snippet]
  }.each do |name, (invoke, klass)|
    it "#{name} parses the live response", vcr: { cassette_name: "integration/#{name}" } do
      result = invoke.call(client)

      if result.is_a?(Kit::Collection)
        expect(result.pagination).to be_a(Kit::Pagination)
        result.first(1).each { |element| expect(element).to be_a(klass) }
      else
        expect(result).to be_a(klass)
      end
    end
  end
end
