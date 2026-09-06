# frozen_string_literal: true

require "json"

module Kit
  module Webhooks
    # One event inside a delivery. `id` is the deduplication key (deliveries
    # are retried whole, so the same event can arrive twice); `type` is the
    # event name (e.g. "subscriber.created"); `created` an ISO 8601 UTC string;
    # `data` the event-specific payload, keyed by resource ("subscriber",
    # "tag", ...), left as a Hash because its shape varies per type.
    Event = Data.define(:id, :type, :created, :data) do
      def self.from(hash)
        new(id: hash["id"], type: hash["type"], created: hash["created"], data: hash["data"] || {})
      end
    end

    # The JSON envelope a webhook endpoint receives (developers.kit.com/
    # webhooks/delivery-format, verified 2026-09-06): { delivery_id, events[] }
    # with 1..100 events of one type, plus the headers X-Kit-Delivery (the same
    # id), X-Kit-Signature, and User-Agent "Kit-Webhooks/2.0". Answer 2xx to
    # acknowledge; anything else is retried (8 attempts over ~41 hours).
    #
    #   delivery = Kit::Webhooks::Delivery.from_request(
    #     request.raw_post, request.headers["X-Kit-Signature"], secret: secret
    #   )
    #   delivery.events.each { |event| handle(event) unless seen?(event.id) }
    # The header carrying the delivery id on each request.
    DELIVERY_HEADER = "X-Kit-Delivery"

    Delivery = Data.define(:delivery_id, :events) do
      def self.from(hash)
        new(delivery_id: hash["delivery_id"], events: Array(hash["events"]).map { |event| Event.from(event) })
      end

      # Parses a raw JSON body. Raises UnexpectedResponseError when it is not
      # the documented envelope.
      def self.parse(payload)
        body = JSON.parse(payload)
        raise UnexpectedResponseError.new("webhook delivery is not a JSON object", body: body) unless body.is_a?(Hash)

        from(body)
      rescue JSON::ParserError => e
        raise UnexpectedResponseError.new("webhook delivery is not valid JSON: #{e.message}", body: payload)
      end

      # Verifies the signature, then parses. The one call a webhook receiver
      # needs; a failed check raises SignatureError before any JSON is read.
      def self.from_request(payload, signature_header, secret:, tolerance: Signature::DEFAULT_TOLERANCE,
                            now: Time.now.to_i)
        Signature.verify!(payload, signature_header, secret: secret, tolerance: tolerance, now: now)
        parse(payload)
      end

      # Every event in a delivery shares one type.
      def type
        events.first&.type
      end
    end
  end
end
