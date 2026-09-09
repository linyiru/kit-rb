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
    RETRYABLE = [RateLimitError, ServerError, TransportError].freeze
    # Verbs safe to replay after a 5xx: the server may have applied the request
    # before failing, and replaying these cannot create a second resource.
    IDEMPOTENT = %i[get head put delete].freeze

    def initialize(config)
      @config = config
      # Built once: an http.rb client is an immutable options chain, safe to
      # share across threads, and each request still opens its own socket.
      # (HTTP.persistent would keep one socket alive but is not thread-safe,
      # and a Client is documented as shareable — so it is not used.)
      # Auth headers are added per request (see #perform), not here, so a token
      # renewed mid-life is picked up by the next request.
      @client = HTTP
                .headers(default_headers)
                .timeout(connect: @config.open_timeout, read: @config.read_timeout, write: @config.write_timeout)
    end

    # Issues a request and returns the parsed JSON body (a Hash) on success.
    # 429s honour `Retry-After`; 5xx use exponential backoff with jitter; both
    # give up after `config.max_retries` and re-raise the typed error.
    #
    # A 429 is retried for every verb (Kit rejected the request, so nothing was
    # applied). A 5xx or a transport failure (timeout, dropped connection) is
    # retried only for idempotent verbs: a POST that created a subscriber
    # before the gateway failed would be created twice.
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
    #
    # With `config.renew` set, a 401 is answered by calling it once and, if it
    # returns a token, retrying the request with that token (every verb: Kit
    # rejected the request unauthenticated, so nothing was applied). A second
    # 401 is raised. A 403 is never renewed.
    def request_with_status(method, path, params: {}, body: nil)
      attempt = 0
      renewed = false
      begin
        used = renewable_token
        handle(perform(method, path, params, body, used), method, path)
      rescue *RETRYABLE => e
        attempt += 1
        raise if attempt > @config.max_retries || !retryable?(method, e)

        backoff_sleep(backoff_for(e, attempt))
        retry
      rescue AuthenticationError
        raise if renewed || !renew_token?(used)

        renewed = true
        retry
      end
    end

    # The default inspect would walk @config and print the credential; this
    # one delegates to @config.auth's masking inspect instead.
    def inspect
      "#<#{self.class.name} base_url=#{@config.base_url.inspect} auth=#{@config.auth.inspect}>"
    end

    private

    def retryable?(method, error)
      error.is_a?(RateLimitError) || IDEMPOTENT.include?(method)
    end

    # The access token this request will be sent with, when renewal is on (nil
    # otherwise): snapshotted so the 401 is attributed to the token that
    # earned it, not to whatever another thread has installed since.
    def renewable_token
      @config.renew && @config.auth.access_token
    end

    # Answers a 401 on `used`. Returns true when the request should be retried:
    # either another thread already installed a newer token (use it, do not
    # renew again), or config.renew returned a replacement. False when there
    # is no callable or it answered nil (cannot renew) — unless a newer token
    # arrived while it was deciding, which is still worth a retry. The
    # replacement is installed compare-and-swap against `used`, so a renewal
    # that completes after a newer token was installed does not roll it back.
    def renew_token?(used)
      renew = @config.renew
      return false unless renew

      auth = @config.auth
      return true if auth.access_token != used

      token = renew.call(used)
      return auth.access_token != used if token.nil?

      auth.replace(token, if_current: used)
      true
    end

    def perform(method, path, params, body, token = nil)
      authed_client(token).request(method, "#{@config.base_url}#{path}", params: params, json: body)
    rescue HTTP::TimeoutError => e
      raise TimeoutError, "#{method.to_s.upcase} #{path} timed out: #{e.message}"
    rescue HTTP::ConnectionError => e
      raise ConnectionError, "#{method.to_s.upcase} #{path} could not connect: #{e.message}"
    rescue HTTP::Error => e
      raise TransportError, "#{method.to_s.upcase} #{path} failed in transport: #{e.message}"
    end

    # The shared client plus the auth header (a new immutable chain each time,
    # so a renewed token is used without rebuilding @client) — for the given
    # OAuth token snapshot, or the credential's current header.
    def authed_client(token = nil)
      @client.headers(token ? @config.auth.headers_for(token) : @config.auth.headers)
    end

    def default_headers
      {
        "Accept" => JSON_TYPE,
        "Content-Type" => JSON_TYPE,
        "User-Agent" => "kit-rb/#{Kit::VERSION}"
      }
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
