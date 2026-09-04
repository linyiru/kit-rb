# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/tags endpoints.
    class Tags < Base
      # GET /v4/tags
      def list(**params)
        collection("/v4/tags", "tags", Objects::Tag, params)
      end

      # POST /v4/tags
      def create(name:)
        one(:post, "/v4/tags", "tag", Objects::Tag, body: { name: name })
      end

      # PUT /v4/tags/:id
      def update(id, name:)
        one(:put, "/v4/tags/#{id}", "tag", Objects::Tag, body: { name: name })
      end

      # POST /v4/tags/:tag_id/subscribers/:id
      def tag_subscriber(tag_id, subscriber_id)
        one(:post, "/v4/tags/#{tag_id}/subscribers/#{subscriber_id}", "subscriber", Objects::Subscriber)
      end

      # DELETE /v4/tags/:tag_id/subscribers/:id
      def remove_subscriber(tag_id, subscriber_id)
        http_delete("/v4/tags/#{tag_id}/subscribers/#{subscriber_id}")
        nil
      end

      # POST /v4/tags/:tag_id/subscribers — tag a subscriber by email address.
      def tag_subscriber_by_email(tag_id, email_address:)
        one(:post, "/v4/tags/#{tag_id}/subscribers", "subscriber", Objects::Subscriber,
            body: { email_address: email_address })
      end

      # DELETE /v4/tags/:tag_id/subscribers — remove a tag from a subscriber by
      # email address (passed as a query parameter).
      def remove_subscriber_by_email(tag_id, email_address:)
        http_delete("/v4/tags/#{tag_id}/subscribers", params: { email_address: email_address })
        nil
      end

      # GET /v4/tags/:tag_id/subscribers
      def subscribers(tag_id, **params)
        collection("/v4/tags/#{tag_id}/subscribers", "subscribers", Objects::Subscriber, params)
      end
    end
  end
end
