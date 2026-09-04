# frozen_string_literal: true

require "securerandom"
require "digest"
require "base64"

module Kit
  module OAuth
    # RFC 7636 Proof Key for Code Exchange (S256), for public clients (SPAs,
    # mobile, CLIs) that cannot hold a client_secret. Generate a challenge before
    # redirecting to the authorize URL, keep the verifier, and send the verifier
    # on the token exchange:
    #
    #   pkce = Kit::OAuth::PKCE.generate
    #   url  = oauth.authorization_url(code_challenge: pkce.code_challenge,
    #                                  code_challenge_method: pkce.code_challenge_method)
    #   # ...redirect, get code back...
    #   token = oauth.exchange_code(code, code_verifier: pkce.code_verifier)
    Challenge = Data.define(:code_verifier, :code_challenge, :code_challenge_method)

    # S256 verifier/challenge generation.
    module PKCE
      METHOD = "S256"

      # Builds a fresh verifier and its S256 challenge.
      def self.generate
        verifier = SecureRandom.urlsafe_base64(64).tr("=", "") # 43–128 unreserved chars
        Challenge.new(
          code_verifier: verifier,
          code_challenge: challenge_for(verifier),
          code_challenge_method: METHOD
        )
      end

      # base64url( SHA256( verifier ) ), unpadded.
      def self.challenge_for(verifier)
        digest = Digest::SHA256.digest(verifier)
        Base64.urlsafe_encode64(digest, padding: false)
      end
    end
  end
end
