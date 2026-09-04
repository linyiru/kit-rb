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
        Objects::Subscriber.from(http_get("/v4/subscribers/#{id}").fetch("subscriber"))
      end

      # POST /v4/subscribers — email_address required; first_name, state, fields optional.
      def create(email_address:, first_name: nil, state: nil, fields: nil)
        body = { email_address: email_address, first_name: first_name,
                 state: state, fields: fields }.compact
        Objects::Subscriber.from(http_post("/v4/subscribers", body: body).fetch("subscriber"))
      end

      # PUT /v4/subscribers/:id
      def update(id, first_name: nil, email_address: nil, fields: nil)
        body = { first_name: first_name, email_address: email_address, fields: fields }.compact
        Objects::Subscriber.from(http_put("/v4/subscribers/#{id}", body: body).fetch("subscriber"))
      end

      # POST /v4/subscribers/:id/unsubscribe
      def unsubscribe(id)
        Objects::Subscriber.from(http_post("/v4/subscribers/#{id}/unsubscribe").fetch("subscriber"))
      end
    end
  end
end
