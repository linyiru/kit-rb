# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/purchases endpoints. All three require OAuth (the API key is not
    # accepted here); create records an external purchase.
    class Purchases < Base
      # GET /v4/purchases
      def list(**params)
        collection("/v4/purchases", "purchases", Objects::Purchase, params)
      end

      # GET /v4/purchases/:id
      def get(id)
        one(:get, "/v4/purchases/#{id}", "purchase", Objects::Purchase)
      end

      # POST /v4/purchases — the request wraps the fields under a "purchase" key.
      # Pass email_address/transaction_id/status/currency/transaction_time,
      # the monetary totals, and a products array.
      def create(**attributes)
        one(:post, "/v4/purchases", "purchase", Objects::Purchase, body: { purchase: attributes })
      end
    end
  end
end
