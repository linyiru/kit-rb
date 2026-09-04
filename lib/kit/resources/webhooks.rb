# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/webhooks endpoints — automation rules that POST to a target URL.
    class Webhooks < Base
      # GET /v4/webhooks
      def list(**params)
        collection("/v4/webhooks", "webhooks", Objects::Webhook, params)
      end

      # POST /v4/webhooks
      def create(target_url:, event:)
        one(:post, "/v4/webhooks", "webhook", Objects::Webhook, body: { target_url: target_url, event: event })
      end

      # DELETE /v4/webhooks/:id
      def delete(id)
        http_delete("/v4/webhooks/#{id}")
        nil
      end
    end
  end
end
