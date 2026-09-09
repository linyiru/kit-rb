# frozen_string_literal: true

module Kit
  # Observability for requests. Configuration#instrumenter receives one event
  # per HTTP round-trip (so a retried request produces one event per attempt):
  #
  #   instrumenter.instrument("request.kit", payload) { ... }
  #
  # The interface is ActiveSupport::Notifications' — pass
  # `ActiveSupport::Notifications` itself in a Rails app — but the gem has no
  # Rails dependency: anything responding to `instrument(name, payload) { }`
  # works. The payload is filled in as the request runs (mutated in place, as
  # ActiveSupport does), so subscribers see the final values:
  #
  #   method:      :get, :post, ...
  #   path:        "/v4/subscribers/42" — never the query string (it can carry
  #                an email address) and never the body
  #   status:      Integer, or nil when no response was received
  #   duration:    seconds, Float
  #   retries:     how many earlier attempts this request has made (0 = first)
  #   retry_after: the parsed Retry-After on a 429, else nil
  #   error:       the Kit error class name when the attempt failed, else nil
  #
  # No header or credential value is ever included; Auth::Credential.mask is
  # for inspect output, not for payloads, which simply omit secrets.
  module Instrumentation
    EVENT = "request.kit"

    # Runs one HTTP attempt inside an instrumenter event, filling the payload
    # in as it completes (including on failure) and re-raising. `block` returns
    # [status, body]. With no instrumenter this is a plain yield.
    #
    # A failure is captured inside the block and re-raised only after
    # `instrument` has returned: ActiveSupport::Notifications would otherwise
    # rescue it and add `:exception` / `:exception_object` to this very
    # payload — the latter a Kit::APIError still holding the response body —
    # which a subscriber forwarding the payload wholesale would then leak.
    def self.around(instrumenter, method, path, retries)
      return yield unless instrumenter

      payload = new_payload(method, path, retries)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = failure = nil
      instrumenter.instrument(EVENT, payload) do
        result = yield
        payload[:status] = result.first
      rescue Error => e
        failure = e
        record_error(payload, e)
      ensure
        payload[:duration] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
      raise failure if failure

      # The request's own result, never the instrumenter's return value:
      # observability must not change what a client method returns. nil here
      # means the instrumenter never yielded, so no request was made.
      result || raise(ConfigurationError, "instrumenter did not yield to the request block")
    end

    # The query string is dropped here, not left to callers: Connection#request
    # is public and a path passed with `?email_address=...` inline must not
    # reach a breadcrumb either.
    def self.new_payload(method, path, retries)
      { method: method, path: path.split(/[?#]/, 2).first.to_s, status: nil, duration: nil,
        retries: retries, retry_after: nil, error: nil }
    end

    def self.record_error(payload, error)
      payload[:error] = error.class.name
      payload[:status] = error.status if error.is_a?(APIError)
      payload[:retry_after] = error.retry_after if error.is_a?(RateLimitError)
    end

    # Wraps a plain Logger as an instrumenter: one debug line per attempt.
    # Used for Configuration#logger; you can also pass it as `instrumenter:`.
    class LoggerInstrumenter
      def initialize(logger)
        @logger = logger
      end

      def instrument(_name, payload)
        yield payload
      ensure
        @logger.debug { format_line(payload) }
      end

      private

      def format_line(payload)
        line = "kit #{payload[:method].to_s.upcase} #{payload[:path]} status=#{payload[:status] || "-"} " \
               "duration=#{format("%.3f", payload[:duration] || 0)}s retries=#{payload[:retries]}"
        line += " retry_after=#{payload[:retry_after]}" if payload[:retry_after]
        line += " error=#{payload[:error]}" if payload[:error]
        line
      end
    end

    # Fans one event out to several instrumenters (instrumenter: and logger:
    # given together). Blocks nest so each sees the same payload.
    class Multi
      def initialize(instrumenters)
        @instrumenters = instrumenters
      end

      # Yields the payload to the caller's block like every instrumenter does,
      # forwarding whatever each layer yields so nesting stays transparent.
      def instrument(name, payload, &block)
        @instrumenters.reverse.inject(block) do |inner, instrumenter|
          ->(yielded) { instrumenter.instrument(name, yielded) { |inner_payload| inner.call(inner_payload) } }
        end.call(payload)
      end
    end

    # Resolves Configuration's instrumenter:/logger: pair into one instrumenter
    # (or nil when neither is set).
    def self.build(instrumenter: nil, logger: nil)
      list = []
      if instrumenter
        unless instrumenter.respond_to?(:instrument)
          raise ConfigurationError, "instrumenter: must respond to #instrument"
        end

        list << instrumenter
      end
      if logger
        raise ConfigurationError, "logger: must respond to #debug" unless logger.respond_to?(:debug)

        list << LoggerInstrumenter.new(logger)
      end
      return nil if list.empty?

      list.size == 1 ? list.first : Multi.new(list)
    end
  end
end
