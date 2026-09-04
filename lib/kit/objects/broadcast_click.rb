# frozen_string_literal: true

module Kit
  module Objects
    # One clicked link in a broadcast's click report
    # (/v4/broadcasts/:id/clicks), with its click totals and rates.
    BroadcastClick = Data.define(
      :id, :url, :unique_clicks, :click_to_delivery_rate, :click_to_open_rate
    ) do
      def self.from(hash)
        new(id: hash["id"], url: hash["url"], unique_clicks: hash["unique_clicks"],
            click_to_delivery_rate: hash["click_to_delivery_rate"],
            click_to_open_rate: hash["click_to_open_rate"])
      end
    end
  end
end
