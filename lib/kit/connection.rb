# frozen_string_literal: true

require "http"
require "json"

module Kit
  # The transport layer: builds requests with http.rb, injects auth and JSON
  # headers, parses responses, and maps non-2xx statuses onto the typed error
  # hierarchy. Resources talk to the API only through this.
  class Connection
    JSON_TYPE = "application/json"

    def initialize(config)
      @config = config
    end

    # Issues a request and returns the parsed JSON body (a Hash) on success.
    #
    # @param method [Symbol] :get, :post, :put, :delete
    # @param path [String] e.g. "/v4/account" (leading slash, no host)
    # @param params [Hash] query string params
    # @param body [Hash, nil] JSON request body
    def request(method, path, params: {}, body: nil)
      response = client.request(
        method,
        "#{@config.base_url}#{path}",
        params: params,
        json: body
      )
      handle(response)
    rescue HTTP::Error => e
      raise Error, "HTTP transport error: #{e.message}"
    end

    private

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

    def handle(response)
      status = response.status.to_i
      parsed = parse(response)
      return parsed if (200..299).cover?(status)

      raise error_for(status, parsed, response)
    end

    def parse(response)
      raw = response.body.to_s
      return nil if raw.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      raw
    end

    def error_for(status, body, response)
      klass = Error.class_for(status)
      if klass == RateLimitError
        klass.new(status: status, body: body, response: response,
                  retry_after: response.headers["Retry-After"]&.to_i)
      else
        klass.new(status: status, body: body, response: response)
      end
    end
  end
end
