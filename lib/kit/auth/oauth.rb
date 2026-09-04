# frozen_string_literal: true

module Kit
  module Auth
    # OAuth 2.0 bearer-token authentication: sends `Authorization: Bearer <token>`.
    #
    # Rate limit is 600 requests / 60s, and OAuth is required for the bulk and
    # purchase-creation endpoints.
    #
    # P0 scope: carry an already-obtained access token. The authorization-code
    # grant (authorize/token URLs at /v4/oauth/*), refresh, and PKCE helper land
    # in P1 — this class is the seam they plug into.
    class OAuth
      AUTHORIZE_URL = "https://api.kit.com/v4/oauth/authorize"
      TOKEN_URL = "https://api.kit.com/v4/oauth/token"

      def initialize(access_token)
        raise ConfigurationError, "OAuth access token cannot be blank" if access_token.nil? || access_token.empty?

        @access_token = access_token
      end

      def headers
        { "Authorization" => "Bearer #{@access_token}" }
      end
    end
  end
end
