# frozen_string_literal: true

module Kit
  module OAuth
    # An OAuth token set from the token endpoint. Kit documents refresh tokens
    # as single-use and returns a new refresh_token on every refresh, so
    # persist the whole Token after each exchange/refresh. Do not rely on the
    # previous refresh token being rejected, though: on 2026-09-08 Kit still
    # accepted it immediately after rotation. If several processes can refresh
    # the same grant, serialise them yourself (one refresh per grant at a time)
    # and have late arrivals adopt the pair that was persisted.
    Token = Data.define(
      :access_token, :refresh_token, :token_type, :expires_in, :scope, :created_at
    ) do
      def self.from(hash)
        new(
          access_token: hash["access_token"],
          refresh_token: hash["refresh_token"],
          token_type: hash["token_type"],
          expires_in: hash["expires_in"],
          scope: hash["scope"],
          created_at: hash["created_at"]
        )
      end

      # Both tokens are masked in #inspect; #to_h still returns the real values
      # for persistence.
      def inspect
        "#<data #{self.class.name} access_token=#{Auth::Credential.mask(access_token)}, " \
          "refresh_token=#{Auth::Credential.mask(refresh_token)}, token_type=#{token_type.inspect}, " \
          "expires_in=#{expires_in.inspect}, scope=#{scope.inspect}, created_at=#{created_at.inspect}>"
      end
      alias_method :to_s, :inspect

      # Unix time the access token expires, or nil when the fields are absent.
      def expires_at
        return nil unless created_at && expires_in

        created_at + expires_in
      end

      # True once past expiry (with an optional leeway in seconds).
      def expired?(now: Time.now.to_i, leeway: 0)
        exp = expires_at
        return false unless exp

        now >= (exp - leeway)
      end

      # True when the token expires within `seconds` from now (or already has),
      # for refreshing proactively before a request would 401. False when the
      # expiry fields are absent.
      def expiring_within?(seconds, now: Time.now.to_i)
        expired?(now: now, leeway: seconds)
      end
    end
  end
end
