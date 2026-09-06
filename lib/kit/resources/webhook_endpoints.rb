# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/webhook_endpoints endpoints — signed webhook delivery, with a
    # rotatable secret.
    #
    # Note: although the OpenAPI spec lists API Key as accepted, the live API
    # rejected an API key here with 401 while /v4/webhooks accepted the same key
    # (verified 2026-09-04) — these endpoints appear to require OAuth in practice.
    class WebhookEndpoints < Base
      # GET /v4/webhook_endpoints
      def list(**params)
        collection("/v4/webhook_endpoints", "webhook_endpoints", Objects::WebhookEndpoint, params)
      end

      # GET /v4/webhook_endpoints/:id
      def get(id)
        one(:get, "/v4/webhook_endpoints/#{path_id(id)}", "webhook_endpoint", Objects::WebhookEndpoint)
      end

      # POST /v4/webhook_endpoints
      def create(url:, events:, name: nil, description: nil)
        one(:post, "/v4/webhook_endpoints", "webhook_endpoint", Objects::WebhookEndpoint,
            body: { url: url, events: events, name: name, description: description }.compact)
      end

      # PATCH /v4/webhook_endpoints/:id — change name/url/description, pause or
      # resume delivery with status: "active" | "disabled", or replace the
      # subscribed events (the list given here replaces the whole set).
      def update(id, name: nil, url: nil, description: nil, status: nil, events: nil)
        body = { name: name, url: url, description: description, status: status, events: events }.compact
        one(:patch, "/v4/webhook_endpoints/#{path_id(id)}", "webhook_endpoint", Objects::WebhookEndpoint, body: body)
      end

      # DELETE /v4/webhook_endpoints/:id
      def delete(id)
        http_delete("/v4/webhook_endpoints/#{path_id(id)}")
        nil
      end

      # POST /v4/webhook_endpoints/:id/rotate_secret
      def rotate_secret(id, force: nil)
        one(:post, "/v4/webhook_endpoints/#{path_id(id)}/rotate_secret", "webhook_endpoint", Objects::WebhookEndpoint,
            body: { force: force }.compact)
      end

      # POST /v4/webhook_endpoints/:id/revoke_previous_secret
      def revoke_previous_secret(id)
        one(:post, "/v4/webhook_endpoints/#{path_id(id)}/revoke_previous_secret", "webhook_endpoint", Objects::WebhookEndpoint)
      end
    end
  end
end
