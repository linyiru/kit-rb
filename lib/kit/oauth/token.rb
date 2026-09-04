# frozen_string_literal: true

module Kit
  module OAuth
    # An OAuth token set from the token endpoint. Kit's refresh tokens are
    # single-use: every refresh returns a *new* refresh_token, so persist the
    # whole Token after each exchange/refresh.
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
    end
  end
end
