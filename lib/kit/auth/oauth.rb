# frozen_string_literal: true

module Kit
  module Auth
    # OAuth 2.0 bearer-token authentication: sends the access token in the
    # `Authorization` header using the Bearer scheme.
    #
    # Rate limit is 600 requests / 60s, and OAuth is required for the bulk and
    # purchase-creation endpoints. Obtaining and refreshing tokens is
    # Kit::OAuth::Client's job; this class only carries an access token — and
    # lets Connection swap it for a renewed one (see Configuration#renew), so
    # reads and the swap are serialised on a mutex.
    class OAuth
      def initialize(access_token)
        @access_token = validate(access_token)
        @lock = Mutex.new
      end

      def headers
        headers_for(access_token)
      end

      # The header for one specific token: Connection snapshots the token a
      # request is sent with, so a 401 can be attributed to that token even if
      # another thread renews in the meantime.
      def headers_for(token)
        { "Authorization" => "Bearer #{token}" }
      end

      # The token currently in use. Handed to the renew callable so it can tell
      # whether another process already persisted a newer pair.
      def access_token
        @lock.synchronize { @access_token }
      end

      # Adopts a renewed token for every request from now on. With
      # `if_current:`, a compare-and-swap: the token is installed only while the
      # current one is still the token the renewal was based on, so a renewal
      # that finishes late cannot roll back a newer token another thread
      # installed. Returns whether the swap happened.
      def replace(access_token, if_current: nil)
        token = validate(access_token)
        @lock.synchronize do
          next false if if_current && @access_token != if_current

          @access_token = token
          true
        end
      end

      def inspect
        "#<#{self.class.name} access_token=#{Credential.mask(access_token)}>"
      end
      alias to_s inspect

      private

      def validate(access_token)
        raise ConfigurationError, "OAuth access token cannot be blank" if access_token.nil? || access_token.empty?

        access_token
      end
    end
  end
end
