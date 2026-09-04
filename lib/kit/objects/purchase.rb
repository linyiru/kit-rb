# frozen_string_literal: true

module Kit
  module Objects
    # A purchase as returned by /v4/purchases. Monetary fields are numbers in the
    # purchase `currency`; `products` is the raw line-item array (each with
    # name/pid/lid/sku/unit_price/quantity).
    Purchase = Data.define(
      :id, :transaction_id, :subscriber_id, :status, :email_address, :currency,
      :transaction_time, :subtotal, :discount, :tax, :total, :products, :source
    ) do
      def self.from(hash)
        new(
          id: hash["id"], transaction_id: hash["transaction_id"],
          subscriber_id: hash["subscriber_id"], status: hash["status"],
          email_address: hash["email_address"], currency: hash["currency"],
          transaction_time: hash["transaction_time"], subtotal: hash["subtotal"],
          discount: hash["discount"], tax: hash["tax"], total: hash["total"],
          products: hash["products"], source: hash["source"]
        )
      end
    end
  end
end
