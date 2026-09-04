# frozen_string_literal: true

require "http"
require "json"
require "uri"

module Kit
  module OAuth
    # Drives the OAuth 2.0 authorization-code flow for a Kit App Store app:
    # build the authorize URL, exchange the returned code for a Token, and
    # refresh it. Kit's OAuth grants a third-party app delegated access to a Kit
    # account owner's data — it is not end-user login for a creator's own site.
    #
    #   oauth = Kit::OAuth::Client.new(client_id: ID, client_secret: SECRET,
    #                                  redirect_uri: "https://app.example/callback")
    #   redirect_to oauth.authorization_url(state: session_token)
    #   token = oauth.exchange_code(params[:code])          # Kit::OAuth::Token
    #   token = oauth.refresh(token.refresh_token)          # single-use refresh
    #   client = Kit::Client.new(access_token: token.access_token)
    #
    # Public clients (SPAs/mobile/CLIs) omit client_secret and use PKCE instead.
    class Client
      AUTHORIZE_PATH = "/v4/oauth/authorize"
      TOKEN_PATH = "/v4/oauth/token"
      REVOKE_PATH = "/v4/oauth/revoke"

      def initialize(client_id:, client_secret: nil, redirect_uri: nil, base_url: DEFAULT_BASE_URL)
        raise ConfigurationError, "client_id is required" if client_id.nil? || client_id.empty?

        @client_id = client_id
        @client_secret = client_secret
        @redirect_uri = redirect_uri
        @base_url = base_url
      end

      # The URL to redirect the Kit account owner to for consent.
      def authorization_url(scope: "public", state: nil, code_challenge: nil,
                            code_challenge_method: nil, tenant_name: nil, redirect_uri: @redirect_uri)
        query = {
          client_id: @client_id,
          response_type: "code",
          redirect_uri: redirect_uri,
          scope: scope,
          state: state,
          code_challenge: code_challenge,
          code_challenge_method: code_challenge_method,
          tenant_name: tenant_name
        }.compact
        "#{@base_url}#{AUTHORIZE_PATH}?#{URI.encode_www_form(query)}"
      end

      # Exchanges an authorization code for a Token. Pass code_verifier for PKCE.
      def exchange_code(code, code_verifier: nil, redirect_uri: @redirect_uri)
        token_request(
          grant_type: "authorization_code",
          code: code,
          client_id: @client_id,
          client_secret: @client_secret,
          redirect_uri: redirect_uri,
          code_verifier: code_verifier
        )
      end

      # Client-credentials grant: exchanges the app's client_id/client_secret for
      # a Bearer token with no user-consent step. Kit issues one (scope "public",
      # ~48h, no refresh_token), but — verified 2026-09-04 — that token is
      # rejected (401) by the v4 resource endpoints: reaching a creator's account
      # data still requires the authorization-code flow (the app must first be
      # authorized on that account). Use this only where a bare app token is
      # expected; for account access, use #authorization_url + #exchange_code.
      def client_credentials(scope: nil)
        token_request(
          grant_type: "client_credentials",
          client_id: @client_id,
          client_secret: @client_secret,
          scope: scope
        )
      end

      # Refreshes a token. Kit refresh tokens are single-use; the returned Token
      # carries a new refresh_token to persist.
      def refresh(refresh_token)
        token_request(
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: @client_id,
          client_secret: @client_secret
        )
      end

      # Revokes an access or refresh token (RFC 7009). Returns true on success;
      # per the RFC a 200 means the token is no longer valid regardless of its
      # prior state, so an unknown/expired/already-revoked token also succeeds.
      # token_type_hint is "access_token" or "refresh_token".
      def revoke(token, token_type_hint: nil)
        response = post_form(REVOKE_PATH, token: token, client_id: @client_id,
                                          client_secret: @client_secret, token_type_hint: token_type_hint)
        return true if (200..299).cover?(response.status.to_i)

        raise OAuthError.new(status: response.status.to_i, body: parse_body(response), response: response)
      end

      private

      def token_request(**form)
        parse_token(post_form(TOKEN_PATH, form))
      end

      def post_form(path, form)
        HTTP
          .headers("Accept" => "application/json", "User-Agent" => "kit-rb/#{Kit::VERSION}")
          .post("#{@base_url}#{path}", form: form.compact)
      rescue HTTP::Error => e
        raise Error, "HTTP transport error: #{e.message}"
      end

      def parse_body(response)
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        nil
      end

      def parse_token(response)
        status = response.status.to_i
        body = parse_body(response)
        return Token.from(body) if (200..299).cover?(status) && body

        raise OAuthError.new(status: status, body: body, response: response)
      end
    end
  end
end
