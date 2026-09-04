# frozen_string_literal: true

module Kit
  module Objects
    # A webhook (an automation rule that POSTs to target_url) as returned by
    # /v4/webhooks. `event` is the raw trigger hash ({ "name" => ..., plus the
    # optional tag_id/form_id/etc. that scope it }).
    Webhook = Data.define(:id, :account_id, :event, :target_url) do
      def self.from(hash)
        new(id: hash["id"], account_id: hash["account_id"],
            event: hash["event"], target_url: hash["target_url"])
      end
    end
  end
end
