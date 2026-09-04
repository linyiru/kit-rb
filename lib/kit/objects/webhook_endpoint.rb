# frozen_string_literal: true

module Kit
  module Objects
    # A webhook endpoint as returned by /v4/webhook_endpoints — the newer signed-
    # delivery model, with a secret that can be rotated. `events` is the list of
    # subscribed event names; `previous_secret_expires_at` is set after a rotate.
    WebhookEndpoint = Data.define(
      :id, :name, :url, :events, :status, :source, :description,
      :created_by_app, :created_at, :previous_secret_expires_at
    ) do
      def self.from(hash)
        new(
          id: hash["id"], name: hash["name"], url: hash["url"], events: hash["events"],
          status: hash["status"], source: hash["source"], description: hash["description"],
          created_by_app: hash["created_by_app"], created_at: hash["created_at"],
          previous_secret_expires_at: hash["previous_secret_expires_at"]
        )
      end
    end
  end
end
