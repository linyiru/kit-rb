# frozen_string_literal: true

module Kit
  module Auth
    # API-key authentication: sends the key in the `X-Kit-Api-Key` header.
    #
    # Simplest way to reach your own account. Rate limit is 120 requests / 60s.
    # Note: Kit's bulk and purchase-creation endpoints require OAuth, not a key.
    class ApiKey
      HEADER = "X-Kit-Api-Key"

      def initialize(key)
        raise ConfigurationError, "API key cannot be blank" if key.nil? || key.empty?

        @key = key
      end

      # Adds the auth header to an outgoing request's header hash.
      def headers
        { HEADER => @key }
      end
    end
  end
end
