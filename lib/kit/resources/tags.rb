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
        object = http_post("/v4/tags", body: { name: name }).fetch("tag")
        Objects::Tag.from(object)
      end

      # PUT /v4/tags/:id
      def update(id, name:)
        object = http_put("/v4/tags/#{id}", body: { name: name }).fetch("tag")
        Objects::Tag.from(object)
      end

      # POST /v4/tags/:tag_id/subscribers/:id
      def tag_subscriber(tag_id, subscriber_id)
        object = http_post("/v4/tags/#{tag_id}/subscribers/#{subscriber_id}")
        Objects::Subscriber.from(object.fetch("subscriber"))
      end

      # DELETE /v4/tags/:tag_id/subscribers/:id
      def remove_subscriber(tag_id, subscriber_id)
        http_delete("/v4/tags/#{tag_id}/subscribers/#{subscriber_id}")
        nil
      end

      # GET /v4/tags/:tag_id/subscribers
      def subscribers(tag_id, **params)
        collection("/v4/tags/#{tag_id}/subscribers", "subscribers", Objects::Subscriber, params)
      end
    end
  end
end
