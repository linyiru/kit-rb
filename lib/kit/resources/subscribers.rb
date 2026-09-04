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

      # POST /v4/subscribers/:id/unsubscribe
      def unsubscribe(id)
        one(:post, "/v4/subscribers/#{id}/unsubscribe", "subscriber", Objects::Subscriber)
      end
    end
  end
end
