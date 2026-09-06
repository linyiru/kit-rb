# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/subscribers endpoints.
    class Subscribers < Base
      # GET /v4/subscribers — a cursor-paginated Collection of Subscriber.
      # Accepts filters as params: after, before, per_page, email_address,
      # status, created_after, created_before, sort_field, sort_order.
      def list(**params)
        collection("/v4/subscribers", "subscribers", Objects::Subscriber, params)
      end

      # GET /v4/subscribers/:id
      def get(id)
        one(:get, "/v4/subscribers/#{id}", "subscriber", Objects::Subscriber)
      end

      # POST /v4/subscribers — email_address required; first_name, state, fields optional.
      def create(email_address:, first_name: nil, state: nil, fields: nil)
        body = { email_address: email_address, first_name: first_name,
                 state: state, fields: fields }.compact
        one(:post, "/v4/subscribers", "subscriber", Objects::Subscriber, body: body)
      end

      # PUT /v4/subscribers/:id
      def update(id, first_name: nil, email_address: nil, fields: nil)
        body = { first_name: first_name, email_address: email_address, fields: fields }.compact
        one(:put, "/v4/subscribers/#{id}", "subscriber", Objects::Subscriber, body: body)
      end

      # POST /v4/subscribers/:id/unsubscribe — the API answers 204 with no body,
      # so this returns nil. Should Kit ever echo the subscriber back, it is
      # returned as a Subscriber instead of being discarded.
      def unsubscribe(id)
        body = http_post("/v4/subscribers/#{id}/unsubscribe")
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
        collection("/v4/subscribers/#{id}/tags", "tags", Objects::Tag, params)
      end

      # GET /v4/subscribers/:id/stats — the subscriber's engagement stats.
      def stats(id)
        one(:get, "/v4/subscribers/#{id}/stats", "subscriber", Objects::SubscriberStats)
      end

      # POST /v4/subscribers/:id/location — set the subscriber's location
      # (a hash of city/state_province/country_code/latitude/longitude/timezone).
      def set_location(id, location:)
        one(:post, "/v4/subscribers/#{id}/location", "subscriber", Objects::Subscriber,
            body: { location: location })
      end

      # DELETE /v4/subscribers/:id/location
      def remove_location(id)
        http_delete("/v4/subscribers/#{id}/location")
        nil
      end
    end
  end
end
