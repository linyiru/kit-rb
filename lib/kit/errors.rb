# frozen_string_literal: true

module Kit
  # Base class for every error the gem raises. Rescue `Kit::Error` to catch all.
  class Error < StandardError; end

  # Raised for configuration problems detected before any request is made
  # (e.g. no credentials supplied).
  class ConfigurationError < Error; end

  # Base for failures below HTTP: the request never got a response. `cause`
  # is the underlying http.rb exception.
  class TransportError < Error; end
  # The connection or read timed out (config.open_timeout / read_timeout).
  class TimeoutError < TransportError; end
  # The connection could not be established or was dropped (DNS, refused,
  # reset, TLS).
  class ConnectionError < TransportError; end

  # Raised when a 2xx response does not have the shape the resource expects
  # (a missing envelope key, a non-JSON body). Distinct from APIError because
  # the request succeeded; the client and the API disagree about the payload.
  # `body` is the parsed (or raw) response body for diagnosis.
  class UnexpectedResponseError < Error
    attr_reader :body

    def initialize(message, body: nil)
      @body = body
      super(message)
    end
  end

  # Base for every error that carries an HTTP response. `status` is the code,
  # `body` the parsed JSON body (or the raw string when it wasn't JSON), and
  # `errors` the `errors` array Kit returns on validation failures. `method`
  # and `path` identify the request that failed (nil for OAuth token errors).
  class APIError < Error
    attr_reader :status, :body, :errors, :response, :method, :path

    def initialize(message = nil, status:, body: nil, response: nil, method: nil, path: nil)
      @status = status
      @body = body
      @response = response
      @method = method
      @path = path
      @errors = body.is_a?(Hash) ? Array(body["errors"]) : []
      super(message || default_message)
    end

    private

    # e.g. "GET /v4/subscribers/1 failed with status 404: Not Found"
    def default_message
      request = method && path ? "#{method.to_s.upcase} #{path}" : "Kit API request"
      base = "#{request} failed with status #{status}"
      @errors.empty? ? base : "#{base}: #{@errors.join(", ")}"
    end
  end

  # 401 — missing or invalid credentials.
  class AuthenticationError < APIError; end
  # 403 — authenticated but not permitted (e.g. an API-key-only call needing OAuth).
  class AuthorizationError < APIError; end
  # 404 — no such resource.
  class NotFoundError < APIError; end
  # 409 — the request conflicts with current state (e.g. rotating a webhook
  # endpoint secret while a previous rotation is still in its grace period).
  class ConflictError < APIError; end
  # 413 — the request exceeds Kit's size quota (the bulk endpoints' enqueued
  # data cap); split the batch.
  class PayloadTooLargeError < APIError; end
  # 422 — the request was well-formed but semantically invalid.
  class UnprocessableEntityError < APIError; end

  # 429 — rate limited. `retry_after` is the seconds to wait, when Kit sends it.
  class RateLimitError < APIError
    attr_reader :retry_after

    def initialize(message = nil, status:, body: nil, response: nil, method: nil, path: nil, retry_after: nil)
      @retry_after = retry_after
      super(message, status: status, body: body, response: response, method: method, path: path)
    end
  end

  # 5xx — a Kit-side failure.
  class ServerError < APIError; end

  # An OAuth token-endpoint failure. `oauth_error` is the RFC 6749 `error` code
  # (e.g. "invalid_grant") and `error_description` its human-readable detail.
  class OAuthError < APIError
    attr_reader :oauth_error, :error_description

    def initialize(status:, body: nil, response: nil)
      if body.is_a?(Hash)
        @oauth_error = body["error"]
        @error_description = body["error_description"]
      end
      super(@oauth_error && "OAuth error: #{@oauth_error} (#{@error_description})",
            status: status, body: body, response: response)
    end
  end

  # Maps an HTTP status to the most specific error class above.
  class Error
    STATUS_CLASSES = {
      401 => AuthenticationError,
      403 => AuthorizationError,
      404 => NotFoundError,
      409 => ConflictError,
      413 => PayloadTooLargeError,
      422 => UnprocessableEntityError,
      429 => RateLimitError
    }.freeze

    def self.class_for(status)
      return ServerError if (500..599).cover?(status)

      STATUS_CLASSES.fetch(status, APIError)
    end
  end
end
