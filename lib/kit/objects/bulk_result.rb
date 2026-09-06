# frozen_string_literal: true

module Kit
  module Objects
    # One rejected item from a bulk call: `item` is the input echoed back by
    # Kit (the hash under "subscriber"/"tag"/... — the key varies per
    # endpoint) and `errors` the validation messages for it.
    BulkFailure = Data.define(:item, :errors) do
      def self.from(hash)
        new(item: hash.except("errors").values.first,
            errors: Array(hash["errors"]))
      end
    end

    # The outcome of a /v4/bulk call. Small batches are applied synchronously
    # (200): `items` are the created/affected records as raw Hashes — their
    # shape is endpoint-specific and partial — and `failures` the rejected
    # inputs. Batches over Kit's inline threshold are queued (202, empty
    # body): `async?` is true, `items`/`failures` are empty, and the full
    # result is POSTed to the request's callback_url when processing ends.
    BulkResult = Data.define(:items, :failures, :async) do
      # `key` is the envelope key of the affected records ("subscribers",
      # "tags", ...), or nil for the delete endpoints, which return failures only.
      def self.from(status, body, key)
        body = {} unless body.is_a?(Hash)
        new(
          items: key ? Array(body[key]) : [],
          failures: Array(body["failures"]).map { |failure| BulkFailure.from(failure) },
          async: status == 202
        )
      end

      def async? = async

      # True when Kit applied the batch now and rejected nothing.
      def success? = !async && failures.empty?
    end
  end
end
