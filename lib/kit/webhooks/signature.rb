# frozen_string_literal: true

require "openssl"

module Kit
  module Webhooks
    # Raised when a delivery's X-Kit-Signature is missing, malformed, stale, or
    # does not match the body under any supplied secret.
    class SignatureError < Error; end

    # Verifies the `X-Kit-Signature` header Kit sends with every webhook-endpoint
    # delivery (verified against developers.kit.com/webhooks/verifying-signatures,
    # 2026-09-06):
    #
    #   X-Kit-Signature: t=1753797130,v1=<hex>[,v1=<hex>]
    #
    # Each v1 is hex(HMAC-SHA256(secret, "#{t}.#{raw_body}")). During a secret
    # rotation the header carries two v1 entries (new and previous secret), so
    # a delivery is valid when any v1 matches any of the secrets you hold.
    #
    #   Kit::Webhooks::Signature.verify!(request.raw_post, request.headers["X-Kit-Signature"],
    #                                    secret: ENV["KIT_WEBHOOK_SECRET"])
    module Signature
      HEADER = "X-Kit-Signature"
      SCHEME = "v1"
      DEFAULT_TOLERANCE = 300 # seconds; Kit's recommended replay window

      Parsed = Data.define(:timestamp, :signatures)

      # hex(HMAC-SHA256(secret, "t.payload")) — what Kit puts in v1.
      def self.compute(secret, timestamp, payload)
        OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
      end

      # Splits the header into its timestamp and v1 signatures. Pairs are kept
      # as a list, not a Hash: a rotation sends two v1 entries.
      def self.parse(header)
        raise SignatureError, "missing #{HEADER} header" if header.nil? || header.strip.empty?

        pairs = header.split(",").map { |pair| pair.strip.split("=", 2) }
        signatures = pairs.filter_map { |key, value| value if key == SCHEME }
        raise SignatureError, "malformed #{HEADER} header: #{header.inspect}" if signatures.empty?

        Parsed.new(timestamp: parse_timestamp(pairs, header), signatures: signatures)
      end

      def self.parse_timestamp(pairs, header)
        value = pairs.find { |key, _| key == "t" }&.last
        raise SignatureError, "malformed #{HEADER} header: #{header.inspect}" if value.nil?
        raise SignatureError, "malformed timestamp in #{HEADER}: #{value.inspect}" unless value.match?(/\A\d+\z/)

        value.to_i
      end
      private_class_method :parse_timestamp

      # True when the payload was signed by one of `secret` (a String, or an
      # Array of Strings while you hold both sides of a rotation) within
      # `tolerance` seconds of `now`. Constant-time comparison.
      def self.verify?(payload, header, secret:, tolerance: DEFAULT_TOLERANCE, now: Time.now.to_i)
        verify!(payload, header, secret: secret, tolerance: tolerance, now: now)
        true
      rescue SignatureError
        false
      end

      # As #verify?, but raises SignatureError describing why the delivery was
      # rejected. `payload` must be the raw request body, byte for byte.
      def self.verify!(payload, header, secret:, tolerance: DEFAULT_TOLERANCE, now: Time.now.to_i)
        secrets = secrets_from(secret)
        parsed = parse(header)
        check_freshness(parsed.timestamp, tolerance, now)
        return true if secrets.any? { |value| matches?(value, parsed, payload) }

        raise SignatureError, "no #{SCHEME} signature matched the payload"
      end

      def self.secrets_from(secret)
        secrets = Array(secret).reject { |value| value.nil? || value.empty? }
        raise ArgumentError, "at least one webhook secret is required" if secrets.empty?

        secrets
      end
      private_class_method :secrets_from

      def self.check_freshness(timestamp, tolerance, now)
        return unless tolerance

        age = (now - timestamp).abs
        raise SignatureError, "timestamp outside tolerance (#{age}s > #{tolerance}s)" if age > tolerance
      end
      private_class_method :check_freshness

      def self.matches?(secret, parsed, payload)
        expected = compute(secret, parsed.timestamp, payload)
        parsed.signatures.any? { |given| OpenSSL.secure_compare(expected, given) }
      end
      private_class_method :matches?
    end
  end
end
