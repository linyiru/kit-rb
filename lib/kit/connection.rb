# frozen_string_literal: true

require "http"
require "json"

module Kit
  # The transport layer: builds requests with http.rb, injects auth and JSON
  # headers, parses responses, maps non-2xx statuses onto the typed error
  # hierarchy, and retries transient failures (429 + 5xx) with backoff.
  # Resources talk to the API only through this.
  class Connection
    JSON_TYPE = "application/json"
    RETRYABLE = [RateLimitError, ServerError].freeze
    # Verbs safe to replay after a 5xx: the server may have applied the request
    # before failing, and replaying these cannot create a second resource.
    IDEMPOTENT = %i[get head put delete].freeze

    def initialize(config)
      @config = config
    end

    # Issues a request and returns the parsed JSON body (a Hash) on success.
    # 429s honour `Retry-After`; 5xx use exponential backoff with jitter; both
    # give up after `config.max_retries` and re-raise the typed error.
    #
    # A 429 is retried for every verb (Kit rejected the request, so nothing was
    # applied). A 5xx is retried only for idempotent verbs: a POST that created
    # a subscriber before the gateway failed would be created twice.
    #
    # @param method [Symbol] :get, :post, :put, :delete
    # @param path [String] e.g. "/v4/account" (leading slash, no host)
    # @param params [Hash] query string params
    # @param body [Hash, nil] JSON request body
    def request(method, path, params: {}, body: nil)
      request_with_status(method, path, params: params, body: body).last
    end

    # As #request, but returns [status, body] for the callers that must tell a
    # 200 (applied now) from a 202 (queued; the bulk endpoints).
    def request_with_status(method, path, params: {}, body: nil)
      attempt = 0
      begin
        handle(perform(method, path, params, body), method, path)
      rescue *RETRYABLE => e
        attempt += 1
        raise if attempt > @config.max_retries || !retryable?(method, e)

        backoff_sleep(backoff_for(e, attempt))
        retry
      end
    end

    private

    def retryable?(method, error)
      error.is_a?(RateLimitError) || IDEMPOTENT.include?(method)
    end

    def perform(method, path, params, body)
      client.request(method, "#{@config.base_url}#{path}", params: params, json: body)
    rescue HTTP::Error => e
      raise Error, "HTTP transport error: #{e.message}"
    end

    def client
      HTTP
        .headers(default_headers)
        .timeout(connect: @config.open_timeout, read: @config.read_timeout)
    end

    def default_headers
      {
        "Accept" => JSON_TYPE,
        "Content-Type" => JSON_TYPE,
        "User-Agent" => "kit-rb/#{Kit::VERSION}"
      }.merge(@config.auth.headers)
    end

    def handle(response, method, path)
      status = response.status.to_i
      parsed = parse(response)
      return [status, parsed] if (200..299).cover?(status)

      raise error_for(status, parsed, response, method, path)
    end

    def parse(response)
      raw = response.body.to_s
      return nil if raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end

    def error_for(status, body, response, method, path)
      klass = Error.class_for(status)
      if klass == RateLimitError
        klass.new(status: status, body: body, response: response, method: method, path: path,
                  retry_after: response.headers["Retry-After"]&.to_i)
      else
        klass.new(status: status, body: body, response: response, method: method, path: path)
      end
    end

    # Seconds to wait before the next attempt: the server's Retry-After when it
    # sent a usable one (429), else exponential backoff (base * 2^(n-1)) with
    # jitter. Both are capped at config.max_backoff — a Retry-After of 300 must
    # not block the caller for five minutes; past the cap the typed error is
    # raised and the caller decides. A Retry-After that parses to 0 (an
    # HTTP-date, or garbage) falls through to the exponential schedule.
    def backoff_for(error, attempt)
      retry_after = error.retry_after if error.is_a?(RateLimitError)
      return [retry_after, @config.max_backoff].min if retry_after&.positive?

      base = @config.retry_backoff * (2**(attempt - 1))
      [base + (rand * @config.retry_backoff), @config.max_backoff].min
    end

    # Extracted so tests can stub the wait instead of really sleeping.
    def backoff_sleep(seconds)
      sleep(seconds)
    end
  end
end
