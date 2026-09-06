# frozen_string_literal: true

module Kit
  module Auth
    # OAuth 2.0 bearer-token authentication: sends `Authorization: Bearer <token>`.
    #
    # Rate limit is 600 requests / 60s, and OAuth is required for the bulk and
    # purchase-creation endpoints. Obtaining and refreshing tokens is
    # Kit::OAuth::Client's job; this class only carries an access token.
    class OAuth
      def initialize(access_token)
        raise ConfigurationError, "OAuth access token cannot be blank" if access_token.nil? || access_token.empty?

        @access_token = access_token
      end

      def headers
        { "Authorization" => "Bearer #{@access_token}" }
      end

      def inspect
        "#<#{self.class.name} access_token=#{Credential.mask(@access_token)}>"
      end
      alias to_s inspect
    end
  end
end
