# frozen_string_literal: true

# The value objects are plain Data classes with no dependency on http.rb, so
# they are loaded here directly: `require "kit/testing"` stays usable without
# the gem's runtime dependencies installed (the standalone guarantee).
%w[account creator_profile subscriber tag custom_field sequence sequence_email broadcast broadcast_stats
   post snippet purchase webhook webhook_endpoint email_stats growth_stats subscriber_stats
   tagged_subscriber].each { |object| require_relative "../objects/#{object}" }
require_relative "../auth/credential"
require_relative "../oauth/token"
require_relative "../tag_names"

module Kit
  module Testing # rubocop:disable Style/Documentation -- documented in lib/kit/testing.rb
    # Typed value objects for `instance_double` returns and direct unit tests,
    # built from the same documented examples as the envelope builders:
    #
    #   Kit::Testing.subscriber(id: 500, email_address: "ada@example.com")
    #   # => #<data Kit::Objects::Subscriber id=500, email_address="ada@example.com", state="active", ...>
    #   Kit::Testing.account_info(plan_type: "free")   # => Kit::Objects::AccountInfo
    #   Kit::Testing.oauth_token(expires_in: 3600)     # => Kit::OAuth::Token
    #   Kit::Testing.tagged_subscriber(tag_names: ["vip", "beta"])
    #
    # Each `<object>` factory is the `<object>_json` builder's envelope object
    # parsed by the Kit::Objects class the resource itself uses, so a factory
    # cannot produce a value the real client could not — the same field
    # validation applies to overrides.
    module Factories
      # <object> factory => the Kit::Objects class that parses its envelope
      # object (the operation comes from Testing::OBJECTS under the same key).
      # `account` is the account object alone; `account_info` below builds the
      # whole GET /v4/account result.
      OBJECT_CLASSES = {
        subscriber: Objects::Subscriber,
        tag: Objects::Tag,
        custom_field: Objects::CustomField,
        sequence: Objects::Sequence,
        sequence_email: Objects::SequenceEmail,
        broadcast: Objects::Broadcast,
        broadcast_stats: Objects::BroadcastStats,
        post: Objects::Post,
        snippet: Objects::Snippet,
        purchase: Objects::Purchase,
        webhook: Objects::Webhook,
        webhook_endpoint: Objects::WebhookEndpoint,
        creator_profile: Objects::CreatorProfile,
        email_stats: Objects::EmailStats,
        growth_stats: Objects::GrowthStats,
        subscriber_stats: Objects::SubscriberStats,
        account: Objects::Account
      }.freeze

      # Kit's documented token response, for Kit::OAuth::Token.
      TOKEN_EXAMPLE = {
        "access_token" => "<ACCESS_TOKEN>",
        "refresh_token" => "<REFRESH_TOKEN>",
        "token_type" => "Bearer",
        "expires_in" => 172_800,
        "scope" => "public",
        "created_at" => 1_700_000_000
      }.freeze

      # The typed object for `factory` (:subscriber, :tag, ...) with overrides
      # applied to its documented example.
      def object(factory, **overrides)
        klass = OBJECT_CLASSES.fetch(factory.to_sym) do
          raise ArgumentError,
                "unknown Kit::Testing factory #{factory.inspect}; known: #{OBJECT_CLASSES.keys.join(", ")}"
        end
        klass.from(attributes(OBJECTS.fetch(factory.to_sym), **overrides))
      end

      # The whole GET /v4/account result. Account overrides apply to
      # `account`; pass `user:` to override user fields (validated against the
      # documented user example like every other override).
      def account_info(user: {}, **account_overrides)
        body = account_json(**account_overrides)
        Objects::AccountInfo.new(
          user: Objects::User.from(merge_known("user", body.fetch("user"), user)),
          account: Objects::Account.from(body.fetch("account"))
        )
      end

      # A Kit::OAuth::Token from Kit's documented token response. `expires_in`
      # 172800 (48 h) and `created_at` are set, so #expires_at / #expired? /
      # #expiring_within? work; pass `created_at:` to place it in time.
      def oauth_token(**overrides)
        OAuth::Token.from(merge_known("token", TOKEN_EXAMPLE, overrides))
      end

      # Subscribers#upsert_and_tag's result, shaped as production would: names
      # normalised and de-duplicated the way Kit matches them (Kit::TagNames,
      # the same code the resource runs), one Tag per distinct name with ids
      # ascending from the tag example's, around a subscriber built from the
      # remaining overrides.
      def tagged_subscriber(tag_names: ["vip"], **subscriber_overrides)
        base = object(:tag)
        tags = TagNames.distinct(tag_names).each_with_index.map { |name, i| object(:tag, id: base.id + i, name: name) }
        Objects::TaggedSubscriber.new(subscriber: object(:subscriber, **subscriber_overrides), tags: tags)
      end

      private

      # `overrides` over `example`, rejecting a key the documented example does
      # not carry — the same rule the envelope builders apply to their types.
      def merge_known(what, example, overrides)
        unknown = overrides.keys.map(&:to_s) - example.keys
        if unknown.any?
          raise ArgumentError,
                "#{unknown.first.inspect} is not a field of #{what.inspect}; known: #{example.keys.join(", ")}"
        end

        example.merge(overrides.transform_keys(&:to_s))
      end
    end

    extend Factories

    # Kit::Testing.subscriber(id: 1) etc., one per OBJECTS entry.
    Factories::OBJECT_CLASSES.each_key do |factory|
      define_singleton_method(factory) { |**overrides| object(factory, **overrides) }
    end
  end
end
