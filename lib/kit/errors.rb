# frozen_string_literal: true

module Kit
  # Base class for every error the gem raises. Rescue `Kit::Error` to catch all.
  class Error < StandardError; end

  # Raised for configuration problems detected before any request is made
  # (e.g. no credentials supplied).
  class ConfigurationError < Error; end

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
    def self.class_for(status)
      case status
      when 401 then AuthenticationError
      when 403 then AuthorizationError
      when 404 then NotFoundError
      when 422 then UnprocessableEntityError
      when 429 then RateLimitError
      when 500..599 then ServerError
      else APIError
      end
    end
  end
end
