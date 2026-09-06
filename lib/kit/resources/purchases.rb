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
        one(:get, "/v4/purchases/#{path_id(id)}", "purchase", Objects::Purchase)
      end

      # POST /v4/purchases — the request wraps the fields under a "purchase"
      # key. The spec marks every field required; `products` is an array of
      # { name, pid, lid, quantity, unit_price, sku }.
      def create(email_address:, transaction_id:, status:, currency:, transaction_time: OMIT, subtotal: OMIT,
                 tax: OMIT, shipping: OMIT, discount: OMIT, total: OMIT, products: OMIT)
        purchase = given(email_address: email_address, transaction_id: transaction_id, status: status,
                         currency: currency, transaction_time: transaction_time, subtotal: subtotal, tax: tax,
                         shipping: shipping, discount: discount, total: total, products: products)
        one(:post, "/v4/purchases", "purchase", Objects::Purchase, body: { purchase: purchase })
      end
    end
  end
end
