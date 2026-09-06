# frozen_string_literal: true

# Contract tests for the non-list operations, pinned against the vendored
# OpenAPI document (see contract_spec.rb for the list envelopes):
#
# 1. single-object envelopes — each method must read the key the spec
#    declares (the stub is keyed off the SPEC, so reading any other key raises
#    UnexpectedResponseError and the example fails);
# 2. request bodies — a method's keyword arguments must all be fields the
#    spec's requestBody declares (a typo or an invented field fails here);
# 3. no-content responses — a method whose operation answers 204 must return
#    nil on an empty body instead of trying to parse an envelope (the bug
#    class behind subscribers.unsubscribe).
module ObjectContractRegistry
  Row = Struct.new(:verb, :spec_path, :runtime_path, :invoke, :klass, keyword_init: true)

  def self.row(verb, spec_path, runtime_path, klass = nil, &invoke)
    Row.new(verb: verb, spec_path: spec_path, runtime_path: runtime_path, invoke: invoke, klass: klass)
  end

  O = Kit::Objects

  OBJECTS = [
    row(:get, "/v4/account/creator_profile", "/v4/account/creator_profile", O::CreatorProfile) do |c|
      c.account.creator_profile
    end,
    row(:get, "/v4/account/email_stats", "/v4/account/email_stats", O::EmailStats) { |c| c.account.email_stats },
    row(:get, "/v4/account/growth_stats", "/v4/account/growth_stats", O::GrowthStats) { |c| c.account.growth_stats },
    row(:post, "/v4/broadcasts", "/v4/broadcasts", O::Broadcast) { |c| c.broadcasts.create(subject: "s") },
    row(:get, "/v4/broadcasts/{id}", "/v4/broadcasts/1", O::Broadcast) { |c| c.broadcasts.get(1) },
    row(:put, "/v4/broadcasts/{id}", "/v4/broadcasts/1", O::Broadcast) { |c| c.broadcasts.update(1, subject: "s") },
    row(:get, "/v4/broadcasts/{broadcast_id}/stats", "/v4/broadcasts/1/stats", O::BroadcastStats) do |c|
      c.broadcasts.stats(1)
    end,
    row(:post, "/v4/custom_fields", "/v4/custom_fields", O::CustomField) { |c| c.custom_fields.create(label: "l") },
    row(:put, "/v4/custom_fields/{id}", "/v4/custom_fields/1", O::CustomField) do |c|
      c.custom_fields.update(1, label: "l")
    end,
    row(:post, "/v4/forms/{form_id}/subscribers", "/v4/forms/1/subscribers", O::Subscriber) do |c|
      c.forms.add_subscriber_by_email(1, email_address: "a@b.c")
    end,
    row(:post, "/v4/forms/{form_id}/subscribers/{id}", "/v4/forms/1/subscribers/2", O::Subscriber) do |c|
      c.forms.add_subscriber(1, 2)
    end,
    row(:get, "/v4/posts/{id}", "/v4/posts/1", O::Post) { |c| c.posts.get(1) },
    row(:post, "/v4/purchases", "/v4/purchases", O::Purchase) do |c|
      c.purchases.create(email_address: "a@b.c", transaction_id: "t", status: "paid", currency: "USD")
    end,
    row(:get, "/v4/purchases/{id}", "/v4/purchases/1", O::Purchase) { |c| c.purchases.get(1) },
    row(:post, "/v4/sequences", "/v4/sequences", O::Sequence) { |c| c.sequences.create(name: "n") },
    row(:get, "/v4/sequences/{id}", "/v4/sequences/1", O::Sequence) { |c| c.sequences.get(1) },
    row(:put, "/v4/sequences/{id}", "/v4/sequences/1", O::Sequence) { |c| c.sequences.update(1, name: "n") },
    row(:post, "/v4/sequences/{sequence_id}/emails", "/v4/sequences/1/emails", O::SequenceEmail) do |c|
      c.sequences.create_email(1, subject: "s", delay_value: 1, delay_unit: "days")
    end,
    row(:get, "/v4/sequences/{sequence_id}/emails/{id}", "/v4/sequences/1/emails/2", O::SequenceEmail) do |c|
      c.sequences.email(1, 2)
    end,
    row(:put, "/v4/sequences/{sequence_id}/emails/{id}", "/v4/sequences/1/emails/2", O::SequenceEmail) do |c|
      c.sequences.update_email(1, 2, subject: "s")
    end,
    row(:post, "/v4/sequences/{sequence_id}/subscribers", "/v4/sequences/1/subscribers", O::Subscriber) do |c|
      c.sequences.add_subscriber_by_email(1, email_address: "a@b.c")
    end,
    row(:post, "/v4/sequences/{sequence_id}/subscribers/{id}", "/v4/sequences/1/subscribers/2", O::Subscriber) do |c|
      c.sequences.add_subscriber(1, 2)
    end,
    row(:post, "/v4/snippets", "/v4/snippets", O::Snippet) do |c|
      c.snippets.create(name: "n", snippet_type: "inline", content: "c")
    end,
    row(:get, "/v4/snippets/{id}", "/v4/snippets/1", O::Snippet) { |c| c.snippets.get(1) },
    row(:put, "/v4/snippets/{id}", "/v4/snippets/1", O::Snippet) { |c| c.snippets.update(1, name: "n") },
    row(:post, "/v4/subscribers", "/v4/subscribers", O::Subscriber) do |c|
      c.subscribers.create(email_address: "a@b.c")
    end,
    row(:get, "/v4/subscribers/{id}", "/v4/subscribers/1", O::Subscriber) { |c| c.subscribers.get(1) },
    row(:put, "/v4/subscribers/{id}", "/v4/subscribers/1", O::Subscriber) do |c|
      c.subscribers.update(1, first_name: "f")
    end,
    row(:post, "/v4/subscribers/{subscriber_id}/location", "/v4/subscribers/1/location", O::Subscriber) do |c|
      c.subscribers.set_location(1, location: {})
    end,
    row(:patch, "/v4/subscribers/{subscriber_id}/location", "/v4/subscribers/1/location", O::Subscriber) do |c|
      c.subscribers.update_location(1, location: {})
    end,
    row(:get, "/v4/subscribers/{subscriber_id}/stats", "/v4/subscribers/1/stats", O::SubscriberStats) do |c|
      c.subscribers.stats(1)
    end,
    row(:post, "/v4/tags", "/v4/tags", O::Tag) { |c| c.tags.create(name: "n") },
    row(:put, "/v4/tags/{id}", "/v4/tags/1", O::Tag) { |c| c.tags.update(1, name: "n") },
    row(:post, "/v4/tags/{tag_id}/subscribers", "/v4/tags/1/subscribers", O::Subscriber) do |c|
      c.tags.tag_subscriber_by_email(1, email_address: "a@b.c")
    end,
    row(:post, "/v4/tags/{tag_id}/subscribers/{id}", "/v4/tags/1/subscribers/2", O::Subscriber) do |c|
      c.tags.tag_subscriber(1, 2)
    end,
    row(:post, "/v4/webhook_endpoints", "/v4/webhook_endpoints", O::WebhookEndpoint) do |c|
      c.webhook_endpoints.create(url: "https://x", events: [])
    end,
    row(:get, "/v4/webhook_endpoints/{id}", "/v4/webhook_endpoints/1", O::WebhookEndpoint) do |c|
      c.webhook_endpoints.get(1)
    end,
    row(:patch, "/v4/webhook_endpoints/{id}", "/v4/webhook_endpoints/1", O::WebhookEndpoint) do |c|
      c.webhook_endpoints.update(1, name: "n")
    end,
    row(:post, "/v4/webhook_endpoints/{id}/rotate_secret", "/v4/webhook_endpoints/1/rotate_secret",
        O::WebhookEndpoint) do |c|
      c.webhook_endpoints.rotate_secret(1)
    end,
    row(:post, "/v4/webhook_endpoints/{id}/revoke_previous_secret", "/v4/webhook_endpoints/1/revoke_previous_secret",
        O::WebhookEndpoint) do |c|
      c.webhook_endpoints.revoke_previous_secret(1)
    end,
    row(:post, "/v4/webhooks", "/v4/webhooks", O::Webhook) { |c| c.webhooks.create(target_url: "https://x", event: {}) }
  ].freeze

  # [resource class, method] => the operation whose requestBody its keywords
  # must come from. `wrap:` names the key the body is nested under.
  BODIES = {
    [Kit::Resources::Broadcasts, :create] => [:post, "/v4/broadcasts"],
    [Kit::Resources::Broadcasts, :update] => [:put, "/v4/broadcasts/{id}"],
    [Kit::Resources::CustomFields, :create] => [:post, "/v4/custom_fields"],
    [Kit::Resources::CustomFields, :update] => [:put, "/v4/custom_fields/{id}"],
    [Kit::Resources::Forms, :add_subscriber] => [:post, "/v4/forms/{form_id}/subscribers/{id}"],
    [Kit::Resources::Forms, :add_subscriber_by_email] => [:post, "/v4/forms/{form_id}/subscribers"],
    [Kit::Resources::Purchases, :create] => [:post, "/v4/purchases", "purchase"],
    [Kit::Resources::Sequences, :create] => [:post, "/v4/sequences"],
    [Kit::Resources::Sequences, :update] => [:put, "/v4/sequences/{id}"],
    [Kit::Resources::Sequences, :create_email] => [:post, "/v4/sequences/{sequence_id}/emails"],
    [Kit::Resources::Sequences, :update_email] => [:put, "/v4/sequences/{sequence_id}/emails/{id}"],
    [Kit::Resources::Sequences, :add_subscriber_by_email] => [:post, "/v4/sequences/{sequence_id}/subscribers"],
    [Kit::Resources::Snippets, :create] => [:post, "/v4/snippets"],
    [Kit::Resources::Snippets, :update] => [:put, "/v4/snippets/{id}"],
    [Kit::Resources::Subscribers, :create] => [:post, "/v4/subscribers"],
    [Kit::Resources::Subscribers, :update] => [:put, "/v4/subscribers/{id}"],
    [Kit::Resources::Subscribers, :set_location] => [:post, "/v4/subscribers/{subscriber_id}/location"],
    [Kit::Resources::Subscribers, :update_location] => [:patch, "/v4/subscribers/{subscriber_id}/location"],
    [Kit::Resources::Tags, :create] => [:post, "/v4/tags"],
    [Kit::Resources::Tags, :update] => [:put, "/v4/tags/{id}"],
    [Kit::Resources::Tags, :tag_subscriber_by_email] => [:post, "/v4/tags/{tag_id}/subscribers"],
    [Kit::Resources::WebhookEndpoints, :create] => [:post, "/v4/webhook_endpoints"],
    [Kit::Resources::WebhookEndpoints, :update] => [:patch, "/v4/webhook_endpoints/{id}"],
    [Kit::Resources::Webhooks, :create] => [:post, "/v4/webhooks"]
  }.freeze

  NO_CONTENT = [
    row(:post, "/v4/subscribers/{id}/unsubscribe", "/v4/subscribers/1/unsubscribe") do |c|
      c.subscribers.unsubscribe(1)
    end,
    row(:delete, "/v4/subscribers/{subscriber_id}/location", "/v4/subscribers/1/location") do |c|
      c.subscribers.remove_location(1)
    end,
    row(:delete, "/v4/custom_fields/{id}", "/v4/custom_fields/1") { |c| c.custom_fields.delete(1) },
    row(:delete, "/v4/sequences/{id}", "/v4/sequences/1") { |c| c.sequences.delete(1) },
    row(:delete, "/v4/sequences/{sequence_id}/emails/{id}", "/v4/sequences/1/emails/2") do |c|
      c.sequences.delete_email(1, 2)
    end,
    row(:delete, "/v4/broadcasts/{id}", "/v4/broadcasts/1") { |c| c.broadcasts.delete(1) },
    row(:delete, "/v4/tags/{tag_id}/subscribers/{id}", "/v4/tags/1/subscribers/2") do |c|
      c.tags.remove_subscriber(1, 2)
    end,
    row(:delete, "/v4/tags/{tag_id}/subscribers", "/v4/tags/1/subscribers?email_address=a%40b.c") do |c|
      c.tags.remove_subscriber_by_email(1, email_address: "a@b.c")
    end,
    row(:delete, "/v4/webhooks/{id}", "/v4/webhooks/1") { |c| c.webhooks.delete(1) },
    row(:delete, "/v4/webhook_endpoints/{id}", "/v4/webhook_endpoints/1") { |c| c.webhook_endpoints.delete(1) }
  ].freeze
end

RSpec.describe "OpenAPI object contract" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  describe "single-object envelopes" do
    ObjectContractRegistry::OBJECTS.each do |row|
      it "#{row.verb.upcase} #{row.spec_path} reads the key the spec declares" do
        envelope = OpenAPIContract.object_endpoints[[row.verb, row.spec_path]]
        expect(envelope).not_to be_nil, "spec declares no single-object 2xx for #{row.verb} #{row.spec_path}"

        stub_kit(row.verb, row.runtime_path, body: { envelope => {} })
        expect(row.invoke.call(client)).to be_a(row.klass)
      end
    end

    it "covers every single-object operation in the spec except GET /v4/account (two objects)" do
      registered = ObjectContractRegistry::OBJECTS.map { |row| [row.verb, row.spec_path] }
      expect(registered).to match_array(OpenAPIContract.object_endpoints.keys)
    end
  end

  describe "request bodies" do
    ObjectContractRegistry::BODIES.each do |(klass, method_name), (verb, path, wrap)|
      it "#{klass.name.split("::").last}##{method_name} only takes fields #{verb.upcase} #{path} documents" do
        documented = wrap ? nested_keys(verb, path, wrap) : OpenAPIContract.request_body_keys(verb, path)
        expect(documented).not_to be_nil, "spec declares no request body for #{verb} #{path}"

        keywords = klass.instance_method(method_name).parameters
                        .filter_map { |type, name| name.to_s if %i[key keyreq].include?(type) }
        expect(keywords - documented).to be_empty,
                                         "#{keywords - documented} are not in the spec body #{documented}"
      end
    end
  end

  describe "no-content responses" do
    ObjectContractRegistry::NO_CONTENT.each do |row|
      it "#{row.verb.upcase} #{row.spec_path} is 204 in the spec and returns nil on an empty body" do
        expect(OpenAPIContract.no_content?(row.verb, row.spec_path))
          .to be(true), "spec does not answer 204 for #{row.verb} #{row.spec_path}"
        stub_request(row.verb, "https://api.kit.com#{row.runtime_path}").to_return(status: 204, body: "")
        expect(row.invoke.call(client)).to be_nil
      end
    end
  end

  def nested_keys(verb, path, wrap)
    schema = OpenAPIContract.document.dig("paths", path, verb.to_s, "requestBody", "content",
                                          "application/json", "schema", "properties", wrap, "properties")
    schema&.keys
  end
end
