# frozen_string_literal: true

require "logger"
require "stringio"

# instrumenter: / logger: — one "request.kit" event per HTTP attempt, with the
# ActiveSupport::Notifications calling convention and a payload that never
# carries params, body or credential values.
RSpec.describe Kit::Instrumentation do
  # Minimal stand-in for ActiveSupport::Notifications: yields the payload,
  # records the (mutated) payload after the block, propagates exceptions.
  let(:recording_instrumenter) do
    Class.new do
      attr_reader :events

      def initialize
        @events = []
      end

      def instrument(name, payload)
        yield payload
      ensure
        @events << [name, payload.dup]
      end
    end
  end

  let(:instrumenter) { recording_instrumenter.new }
  let(:client) { Kit::Client.new(api_key: "secret", instrumenter: instrumenter, max_retries: 1) }
  let(:url) { "https://api.kit.com/v4/account" }
  let(:json) { { "Content-Type" => "application/json" } }
  let(:ok) do
    { status: 200, headers: json,
      body: JSON.generate("user" => { "email" => "<EMAIL>" }, "account" => { "id" => 1 }) }
  end

  before { allow_any_instance_of(Kit::Connection).to receive(:backoff_sleep) }

  it "emits one request.kit event with method, path, status, duration and retries for a success" do
    stub_request(:get, url).to_return(ok)
    client.account.get

    expect(instrumenter.events.size).to eq(1)
    name, payload = instrumenter.events.first
    expect(name).to eq("request.kit")
    expect(payload).to include(method: :get, path: "/v4/account", status: 200, retries: 0, retry_after: nil, error: nil)
    expect(payload[:duration]).to be_a(Float).and be >= 0
  end

  it "emits one event per attempt when a 429 is retried, with retries and retry_after" do
    stub_request(:get, url).to_return({ status: 429, headers: json.merge("Retry-After" => "7"), body: "{}" }, ok)
    client.account.get

    expect(instrumenter.events.map { |_, p| p.values_at(:status, :retries, :retry_after, :error) }).to eq([
                                                                                                            [429, 0, 7,
                                                                                                             "Kit::RateLimitError"],
                                                                                                            [200, 1,
                                                                                                             nil, nil]
                                                                                                          ])
  end

  it "records a transport failure with a nil status and the error class" do
    stub_request(:post, "https://api.kit.com/v4/tags").to_timeout

    expect { client.tags.create(name: "vip") }.to raise_error(Kit::TimeoutError)
    _, payload = instrumenter.events.first
    expect(payload).to include(method: :post, path: "/v4/tags", status: nil, error: "Kit::TimeoutError")
    expect(instrumenter.events.size).to eq(1) # a POST is not retried after a transport failure
  end

  it "records a non-retried API error with its status" do
    stub_request(:get, "https://api.kit.com/v4/subscribers/1")
      .to_return(status: 404, headers: json, body: JSON.generate("errors" => ["Not found"]))

    expect { client.subscribers.get(1) }.to raise_error(Kit::NotFoundError)
    _, payload = instrumenter.events.first
    expect(payload).to include(status: 404, error: "Kit::NotFoundError", path: "/v4/subscribers/1")
  end

  it "records both attempts of a 401 renewed once" do
    stub_request(:get, url).with(headers: { "Authorization" => "Bearer old" })
                           .to_return(status: 401, headers: json, body: JSON.generate("errors" => ["invalid"]))
    stub_request(:get, url).with(headers: { "Authorization" => "Bearer new" }).to_return(ok)
    client = Kit::Client.new(access_token: "old", renew: ->(_) { "new" }, instrumenter: instrumenter)
    client.account.get

    expect(instrumenter.events.map { |_, p| p.values_at(:status, :retries, :error) })
      .to eq([[401, 0, "Kit::AuthenticationError"], [200, 1, nil]])
  end

  it "counts a renewal retry after a 429 retry in retries (429 → 401 → 200 is 0, 1, 2)" do
    unauthorized = { status: 401, headers: json, body: JSON.generate("errors" => ["invalid"]) }
    throttled = { status: 429, headers: json.merge("Retry-After" => "1"), body: "{}" }
    stub_request(:get, url).with(headers: { "Authorization" => "Bearer old" }).to_return(throttled, unauthorized)
    stub_request(:get, url).with(headers: { "Authorization" => "Bearer new" }).to_return(ok)
    client = Kit::Client.new(access_token: "old", renew: ->(_) { "new" }, instrumenter: instrumenter, max_retries: 1)
    client.account.get

    expect(instrumenter.events.map { |_, p| p.values_at(:status, :retries) }).to eq([[429, 0], [401, 1], [200, 2]])
  end

  it "returns the request result even when the instrumenter returns something else" do
    swallowing = Class.new do
      def instrument(_name, payload)
        yield payload
        :recorded # a duck-typed instrumenter that returns its own bookkeeping
      end
    end.new
    stub_request(:get, url).to_return(ok)

    expect(Kit::Client.new(api_key: "k", instrumenter: swallowing).account.get.account.id).to eq(1)
  end

  it "raises ConfigurationError if the instrumenter never yields (no request was made)" do
    silent = Class.new { def instrument(_name, _payload) = :skipped }.new
    expect { Kit::Client.new(api_key: "k", instrumenter: silent).account.get }
      .to raise_error(Kit::ConfigurationError, /did not yield/)
    expect(a_request(:get, url)).not_to have_been_made
  end

  it "never includes params, body, headers or the credential in the payload" do
    created = ok.merge(body: JSON.generate("subscriber" => { "id" => 1 }))
    stub_request(:post, "https://api.kit.com/v4/subscribers").to_return(created)
    stub_request(:delete, %r{/v4/tags/1/subscribers\?email_address=}).to_return(status: 204, body: "")
    client.subscribers.create(email_address: "ada@example.com", first_name: "Ada")
    client.tags.remove_subscriber_by_email(1, email_address: "ada@example.com")

    instrumenter.events.map(&:last).each do |payload|
      expect(payload.keys).to contain_exactly(:method, :path, :status, :duration, :retries, :retry_after, :error)
      dumped = payload.inspect
      expect(dumped).not_to include("ada@example.com", "Ada", "secret", "X-Kit-Api-Key", "Authorization")
    end
    expect(instrumenter.events.last.last[:path]).to eq("/v4/tags/1/subscribers") # query string dropped
  end

  it "strips a query string a caller inlined into the path itself" do
    stub_request(:get, "https://api.kit.com/v4/subscribers?email_address=ada@example.com").to_return(ok)
    connection = Kit::Connection.new(Kit::Configuration.new(api_key: "k", instrumenter: instrumenter))
    connection.request(:get, "/v4/subscribers?email_address=ada@example.com")

    payload = instrumenter.events.first.last
    expect(payload[:path]).to eq("/v4/subscribers")
    expect(payload.inspect).not_to include("ada@example.com")
  end

  it "makes the mutated payload visible to an ActiveSupport-style subscriber that captures it before the block ends" do
    captured = nil
    as_like = Class.new do
      define_method(:instrument) do |_name, payload, &block|
        captured = payload # AS passes this very Hash to subscribers
        block.call(payload)
      end
    end.new
    stub_request(:get, url).to_return(ok)
    Kit::Client.new(api_key: "k", instrumenter: as_like).account.get

    expect(captured).to include(status: 200)
    expect(captured[:duration]).to be_a(Float)
  end

  # Faithful stand-in for ActiveSupport::Notifications.instrument: rescues an
  # exception from the block, records it on the payload, re-raises.
  let(:active_support_like) do
    Class.new do
      attr_reader :payloads

      def initialize
        @payloads = []
      end

      def instrument(_name, payload)
        yield payload
      rescue Exception => e # rubocop:disable Lint/RescueException
        payload[:exception] = [e.class.name, e.message]
        payload[:exception_object] = e
        raise
      ensure
        @payloads << payload
      end
    end
  end

  it "never lets ActiveSupport attach the exception (and its response body) to a failed event's payload" do
    as = active_support_like.new
    stub_request(:get, "https://api.kit.com/v4/subscribers/1")
      .to_return(status: 404, headers: json, body: JSON.generate("errors" => ["No subscriber ada@example.com"]))

    expect { Kit::Client.new(api_key: "k", instrumenter: as).subscribers.get(1) }.to raise_error(Kit::NotFoundError)

    payload = as.payloads.first
    expect(payload.keys).to contain_exactly(:method, :path, :status, :duration, :retries, :retry_after, :error)
    expect(payload).to include(status: 404, error: "Kit::NotFoundError")
    expect(payload.inspect).not_to include("ada@example.com")
  end

  describe "logger:" do
    def duration_of(line) = line[/duration=(\d+\.\d{3})s/, 1]

    let(:io) { StringIO.new }
    let(:logger) { Logger.new(io).tap { |l| l.level = Logger::DEBUG } }

    it "logs one debug line per attempt with the payload fields" do
      stub_request(:get, url).to_return({ status: 429, headers: json.merge("Retry-After" => "3"), body: "{}" }, ok)
      Kit::Client.new(api_key: "secret", logger: logger, max_retries: 1).account.get

      lines = io.string.lines.map(&:chomp)
      expect(lines.size).to eq(2)
      expect(lines[0]).to match(/DEBUG/)
      expect(lines[0]).to end_with("kit GET /v4/account status=429 duration=#{duration_of(lines[0])}s retries=0 " \
                                   "retry_after=3 error=Kit::RateLimitError")
      expect(lines[1]).to match(%r{kit GET /v4/account status=200 duration=\d+\.\d{3}s retries=1$})
      expect(io.string).not_to include("secret")
    end

    it "logs a transport failure with status=-" do
      stub_request(:get, url).to_timeout
      client = Kit::Client.new(api_key: "secret", logger: logger, max_retries: 0)
      expect { client.account.get }.to raise_error(Kit::TimeoutError)
      expect(io.string).to include("status=- ").and include("error=Kit::TimeoutError")
    end

    it "stays silent above debug level" do
      logger.level = Logger::INFO
      stub_request(:get, url).to_return(ok)
      Kit::Client.new(api_key: "k", logger: logger).account.get
      expect(io.string).to be_empty
    end

    it "fans out to both when instrumenter: and logger: are given" do
      stub_request(:get, url).to_return(ok)
      Kit::Client.new(api_key: "k", instrumenter: instrumenter, logger: logger).account.get
      expect(instrumenter.events.size).to eq(1)
      expect(io.string.lines.size).to eq(1)
    end

    it "yields the payload through the combined instrumenter like a single one does" do
      combined = Kit::Configuration.new(api_key: "k", instrumenter: instrumenter, logger: logger).instrumenter
      payload = { method: :get, path: "/x", status: nil, duration: nil, retries: 0, retry_after: nil, error: nil }
      strict = ->(yielded) { yielded[:status] = 204 } # arity 1: fails unless the payload is forwarded

      result = combined.instrument("request.kit", payload) { |yielded| strict.call(yielded) && :done }

      expect(result).to eq(:done)
      expect(payload[:status]).to eq(204)
      expect(instrumenter.events.first.last[:status]).to eq(204)
      expect(io.string).to include("status=204")
    end
  end

  describe "configuration" do
    it "rejects an instrumenter without #instrument" do
      expect { Kit::Client.new(api_key: "k", instrumenter: Object.new) }
        .to raise_error(Kit::ConfigurationError, /respond to #instrument/)
    end

    it "rejects a logger without #debug" do
      expect { Kit::Client.new(api_key: "k", logger: "nope") }
        .to raise_error(Kit::ConfigurationError, /respond to #debug/)
    end

    it "is nil by default and adds no overhead" do
      expect(Kit::Configuration.new(api_key: "k").instrumenter).to be_nil
    end
  end
end
