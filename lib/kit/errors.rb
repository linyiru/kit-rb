# frozen_string_literal: true

module Kit
  # Base class for every error the gem raises. Rescue `Kit::Error` to catch all.
  class Error < StandardError; end

  # Raised for configuration problems detected before any request is made
  # (e.g. no credentials supplied).
  class ConfigurationError < Error; end

  # Base for every error that carries an HTTP response. `status` is the code,
  # `body` the parsed JSON body (or the raw string when it wasn't JSON), and
  # `errors` the `errors` array Kit returns on validation failures.
  class APIError < Error
    attr_reader :status, :body, :errors, :response

    def initialize(message = nil, status:, body: nil, response: nil)
      @status = status
      @body = body
      @response = response
      @errors = body.is_a?(Hash) ? Array(body["errors"]) : []
      super(message || default_message)
    end

    private

    def default_message
      base = "Kit API request failed with status #{status}"
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

    def initialize(message = nil, status:, body: nil, response: nil, retry_after: nil)
      @retry_after = retry_after
      super(message, status: status, body: body, response: response)
    end
  end

  # 5xx — a Kit-side failure.
  class ServerError < APIError; end

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
