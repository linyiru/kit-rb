# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/bulk endpoints — batch operations that all require OAuth. Each call
    # takes an array of items and an optional callback_url and returns a
    # BulkResult: the affected records under `items`, the rejected inputs under
    # `failures`, and `async?` when Kit queued the batch (202) and will report
    # the outcome to callback_url instead.
    class Bulk < Base
      # POST /v4/bulk/subscribers
      def create_subscribers(subscribers, callback_url: nil)
        bulk(:post, "/v4/bulk/subscribers", "subscribers", subscribers: subscribers, callback_url: callback_url)
      end

      # POST /v4/bulk/custom_fields
      def create_custom_fields(custom_fields, callback_url: nil)
        bulk(:post, "/v4/bulk/custom_fields", "custom_fields",
             custom_fields: custom_fields, callback_url: callback_url)
      end

      # POST /v4/bulk/custom_fields/subscribers
      def update_custom_field_values(custom_field_values, callback_url: nil)
        bulk(:post, "/v4/bulk/custom_fields/subscribers", "custom_field_values",
             custom_field_values: custom_field_values, callback_url: callback_url)
      end

      # POST /v4/bulk/forms/subscribers
      def add_subscribers_to_forms(additions, callback_url: nil)
        bulk(:post, "/v4/bulk/forms/subscribers", "subscribers", additions: additions, callback_url: callback_url)
      end

      # POST /v4/bulk/tags
      def create_tags(tags, callback_url: nil)
        bulk(:post, "/v4/bulk/tags", "tags", tags: tags, callback_url: callback_url)
      end

      # DELETE /v4/bulk/tags — returns failures only.
      def delete_tags(tags, callback_url: nil)
        bulk(:delete, "/v4/bulk/tags", nil, tags: tags, callback_url: callback_url)
      end

      # POST /v4/bulk/tags/subscribers
      def tag_subscribers(taggings, callback_url: nil)
        bulk(:post, "/v4/bulk/tags/subscribers", "subscribers", taggings: taggings, callback_url: callback_url)
      end

      # DELETE /v4/bulk/tags/subscribers — returns failures only.
      def remove_tag_subscribers(taggings, callback_url: nil)
        bulk(:delete, "/v4/bulk/tags/subscribers", nil, taggings: taggings, callback_url: callback_url)
      end

      private

      def bulk(verb, path, key, **body)
        status, response = @connection.request_with_status(verb, path, body: body.compact)
        Objects::BulkResult.from(status, response, key)
      end
    end
  end
end
