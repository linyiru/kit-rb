# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/tags endpoints.
    class Tags < Base
      def initialize(connection)
        super
        @ensured = {}
        @ensured_lock = Mutex.new
        @generation = 0 # bumped by #update and refresh so an in-flight #ensure cannot publish a stale entry
      end

      # Kit matches tag names case-insensitively and v3 consumers carry over a
      # "find_tag_by_name or create" dance that v4 no longer needs. This is the
      # canonical form of a name for that matching: runs of Unicode whitespace
      # (`[[:space:]]`, not `\s`, so a fullwidth or typographic space cannot
      # mint a look-alike tag) collapsed to one ASCII space and trimmed.
      # Raises ArgumentError when nothing is left.
      def self.normalize_name(name)
        normalized = name.to_s.gsub(/[[:space:]]+/, " ").strip
        raise ArgumentError, "tag name must not be blank" if normalized.empty?

        normalized
      end

      # The key two names share when Kit would treat them as the same tag.
      def self.name_key(name)
        normalize_name(name).downcase
      end

      # GET /v4/tags
      def list(**params)
        collection("/v4/tags", "tags", Objects::Tag, params)
      end

      # POST /v4/tags — idempotent on name, matched case-insensitively: an
      # existing tag is returned (200) rather than duplicated (201). Safe to
      # replay. There is no single-tag delete in v4; use Bulk#delete_tags.
      def create(name:)
        one(:post, "/v4/tags", "tag", Objects::Tag, body: { name: name })
      end

      # Find-or-create by name, cached for the client's lifetime. `create` is
      # already the cheapest find-or-create (no list-and-paginate), but one
      # call per tag per subscriber is wasteful across a batch, so the Tag is
      # remembered under its case-insensitive, whitespace-normalised key. A
      # tag deleted outside this client stays cached until `refresh: true`
      # (Subscribers#upsert_and_tag does that on a 404).
      #
      # Thread-safe. The request is made outside the lock, so two threads
      # racing on one new name may both call `create` (idempotent); the first
      # to publish wins and every caller gets that same Tag. A result is
      # published only if no #update or refresh ran meanwhile (generation
      # unchanged): a rename or eviction that completed while the create was
      # in flight must not be undone by the older response, which is then
      # returned to its caller but not cached.
      def ensure(name:, refresh: false)
        normalized = self.class.normalize_name(name)
        key = normalized.downcase
        cached, generation = @ensured_lock.synchronize do
          if refresh
            @ensured.delete(key)
            @generation += 1
          end
          [@ensured[key], @generation]
        end
        return cached if cached

        tag = create(name: normalized)
        published = @ensured_lock.synchronize { @ensured[key] ||= tag if @generation == generation }
        published || tag
      end

      # PUT /v4/tags/:id — renames the tag. The ensure cache forgets every entry
      # for this id (an old name must not answer with the renamed tag) and
      # remembers the tag under its new name.
      def update(id, name:)
        tag = one(:put, "/v4/tags/#{path_id(id)}", "tag", Objects::Tag, body: { name: name })
        @ensured_lock.synchronize do
          @generation += 1
          @ensured.delete_if { |_, cached| cached.id == tag.id }
          @ensured[self.class.name_key(tag.name)] = tag if tag.name
        end
        tag
      end

      # POST /v4/tags/:tag_id/subscribers/:id
      def tag_subscriber(tag_id, subscriber_id)
        one(:post, "/v4/tags/#{path_id(tag_id)}/subscribers/#{path_id(subscriber_id)}", "subscriber", Objects::Subscriber)
      end

      # DELETE /v4/tags/:tag_id/subscribers/:id
      def remove_subscriber(tag_id, subscriber_id)
        http_delete("/v4/tags/#{path_id(tag_id)}/subscribers/#{path_id(subscriber_id)}")
        nil
      end

      # POST /v4/tags/:tag_id/subscribers — tag a subscriber by email address.
      def tag_subscriber_by_email(tag_id, email_address:)
        one(:post, "/v4/tags/#{path_id(tag_id)}/subscribers", "subscriber", Objects::Subscriber,
            body: { email_address: email_address })
      end

      # DELETE /v4/tags/:tag_id/subscribers — remove a tag from a subscriber by
      # email address (passed as a query parameter).
      def remove_subscriber_by_email(tag_id, email_address:)
        http_delete("/v4/tags/#{path_id(tag_id)}/subscribers", params: { email_address: email_address })
        nil
      end

      # GET /v4/tags/:tag_id/subscribers
      def subscribers(tag_id, **params)
        collection("/v4/tags/#{path_id(tag_id)}/subscribers", "subscribers", Objects::Subscriber, params)
      end
    end
  end
end
