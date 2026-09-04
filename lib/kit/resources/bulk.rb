# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/bulk endpoints — batch operations that all require OAuth. Each call
    # takes an array of items and an optional callback_url, and returns the raw
    # result hash: the created/affected items under their resource key plus a
    # "failures" array. Large batches are processed asynchronously and reported
    # to callback_url; the response still carries whatever completed inline.
    class Bulk < Base
      # POST /v4/bulk/subscribers
      def create_subscribers(subscribers, callback_url: nil)
        post("/v4/bulk/subscribers", subscribers: subscribers, callback_url: callback_url)
      end

      # POST /v4/bulk/custom_fields
      def create_custom_fields(custom_fields, callback_url: nil)
        post("/v4/bulk/custom_fields", custom_fields: custom_fields, callback_url: callback_url)
      end

      # POST /v4/bulk/custom_fields/subscribers
      def update_custom_field_values(custom_field_values, callback_url: nil)
        post("/v4/bulk/custom_fields/subscribers",
             custom_field_values: custom_field_values, callback_url: callback_url)
      end

      # POST /v4/bulk/forms/subscribers
      def add_subscribers_to_forms(additions, callback_url: nil)
        post("/v4/bulk/forms/subscribers", additions: additions, callback_url: callback_url)
      end

      # POST /v4/bulk/tags
      def create_tags(tags, callback_url: nil)
        post("/v4/bulk/tags", tags: tags, callback_url: callback_url)
      end

      # DELETE /v4/bulk/tags
      def delete_tags(tags, callback_url: nil)
        delete("/v4/bulk/tags", tags: tags, callback_url: callback_url)
      end

      # POST /v4/bulk/tags/subscribers
      def tag_subscribers(taggings, callback_url: nil)
        post("/v4/bulk/tags/subscribers", taggings: taggings, callback_url: callback_url)
      end

      # DELETE /v4/bulk/tags/subscribers
      def remove_tag_subscribers(taggings, callback_url: nil)
        delete("/v4/bulk/tags/subscribers", taggings: taggings, callback_url: callback_url)
      end

      private

      def post(path, **body)
        http_post(path, body: body.compact)
      end

      def delete(path, **body)
        http_delete(path, body: body.compact)
      end
    end
  end
end
