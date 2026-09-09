# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/subscribers endpoints.
    class Subscribers < Base
      # `tags` is the client's Tags resource, shared so #upsert_and_tag benefits
      # from (and warms) the same ensure cache as client.tags.
      def initialize(connection, tags: nil)
        super(connection)
        @tags = tags || Tags.new(connection)
      end

      # GET /v4/subscribers — a cursor-paginated Collection of Subscriber.
      # Accepts filters as params: after, before, per_page, email_address,
      # status, created_after, created_before, sort_field, sort_order.
      def list(**params)
        collection("/v4/subscribers", "subscribers", Objects::Subscriber, params)
      end

      # GET /v4/subscribers/:id
      def get(id)
        one(:get, "/v4/subscribers/#{path_id(id)}", "subscriber", Objects::Subscriber)
      end

      # POST /v4/subscribers — email_address required; first_name, state, fields
      # optional. An upsert: an existing email address has its first_name
      # updated rather than being duplicated, so the call is safe to replay.
      def create(email_address:, first_name: nil, state: nil, fields: nil)
        body = { email_address: email_address, first_name: first_name,
                 state: state, fields: fields }.compact
        one(:post, "/v4/subscribers", "subscriber", Objects::Subscriber, body: body)
      end

      # The v4 replacement for v3's tag-subscribe: upsert the subscriber, then
      # ensure each tag by name and apply it. Names are de-duplicated the way
      # Kit matches them (case-insensitive, whitespace-normalised: see
      # Tags.normalize_name), so `["VIP", "vip"]` applies one tag, and the
      # result lists exactly the tags applied. Tag ids come from the client's
      # ensure cache; if a cached tag has since been deleted (404 on tagging)
      # it is re-ensured once and the tagging retried.
      #
      # Every step is safe to replay (create is an upsert, tags.create and
      # tagging are idempotent), so a job may re-run the whole call.
      #
      # @return [Kit::Objects::TaggedSubscriber] subscriber + tags applied
      def upsert_and_tag(email_address:, tag_names:, first_name: nil, state: nil, fields: nil)
        names = distinct_tag_names(tag_names)
        subscriber = create(email_address: email_address, first_name: first_name, state: state, fields: fields)
        applied = names.map { |name| apply_tag(subscriber, name) }
        Objects::TaggedSubscriber.new(subscriber: subscriber, tags: applied)
      end

      # PUT /v4/subscribers/:id
      def update(id, first_name: nil, email_address: nil, fields: nil)
        body = { first_name: first_name, email_address: email_address, fields: fields }.compact
        one(:put, "/v4/subscribers/#{path_id(id)}", "subscriber", Objects::Subscriber, body: body)
      end

      # POST /v4/subscribers/:id/unsubscribe — the API answers 204 with no body,
      # so this returns nil. Should Kit ever echo the subscriber back, it is
      # returned as a Subscriber instead of being discarded.
      def unsubscribe(id)
        body = http_post("/v4/subscribers/#{path_id(id)}/unsubscribe")
        return nil unless body.is_a?(Hash) && body.key?("subscriber")

        Objects::Subscriber.from(body.fetch("subscriber"))
      end

      # POST /v4/subscribers/filter — the same filters as #list, sent in the
      # request rather than the query string; returns a cursor-paginated Collection.
      def filter(**params)
        collection("/v4/subscribers/filter", "subscribers", Objects::Subscriber, params, verb: :post)
      end

      # GET /v4/subscribers/:id/tags — the tags applied to a subscriber.
      def tags(id, **params)
        collection("/v4/subscribers/#{path_id(id)}/tags", "tags", Objects::Tag, params)
      end

      # GET /v4/subscribers/:id/stats — the subscriber's engagement stats.
      # Bound the window with email_sent_after / email_sent_before (yyyy-mm-dd).
      def stats(id, email_sent_after: nil, email_sent_before: nil)
        params = { email_sent_after: email_sent_after, email_sent_before: email_sent_before }.compact
        one(:get, "/v4/subscribers/#{path_id(id)}/stats", "subscriber", Objects::SubscriberStats, params: params)
      end

      # POST /v4/subscribers/:id/location — set the subscriber's location
      # (a hash of city/state_province/country_code/latitude/longitude/timezone).
      def set_location(id, location:)
        one(:post, "/v4/subscribers/#{path_id(id)}/location", "subscriber", Objects::Subscriber,
            body: { location: location })
      end

      # PATCH /v4/subscribers/:id/location — replace a pinned location. Kit
      # requires the full location (all six keys) on update, not a partial.
      def update_location(id, location:)
        one(:patch, "/v4/subscribers/#{path_id(id)}/location", "subscriber", Objects::Subscriber,
            body: { location: location })
      end

      # DELETE /v4/subscribers/:id/location
      def remove_location(id)
        http_delete("/v4/subscribers/#{path_id(id)}/location")
        nil
      end

      private

      # Normalised names, first spelling wins, one per case-insensitive key.
      def distinct_tag_names(tag_names)
        Array(tag_names).map { |name| Tags.normalize_name(name) }.uniq(&:downcase)
      end

      def apply_tag(subscriber, name)
        tag = @tags.ensure(name: name)
        begin
          @tags.tag_subscriber(tag.id, subscriber.id)
        rescue NotFoundError
          # The cached tag no longer exists: drop it, ensure again, retry once.
          tag = @tags.ensure(name: name, refresh: true)
          @tags.tag_subscriber(tag.id, subscriber.id)
        end
        tag
      end
    end
  end
end
