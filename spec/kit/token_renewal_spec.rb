# frozen_string_literal: true

# `renew:` — on a 401 the connection asks the callable for a replacement access
# token once and retries with it. The callable owns refreshing, persistence and
# locking; the gem only owns "once, on 401, not on 403".
RSpec.describe "Token renewal (renew:)" do
  let(:url) { "https://api.kit.com/v4/account" }
  let(:ok_body) do
    JSON.generate("user" => { "email" => "<EMAIL>", "id" => 1 }, "account" => { "id" => 2, "name" => "" })
  end

  def unauthorized
    { status: 401, body: JSON.generate("errors" => ["The access token is invalid"]),
      headers: { "Content-Type" => "application/json" } }
  end

  def ok
    { status: 200, body: ok_body, headers: { "Content-Type" => "application/json" } }
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  it "retries a 401 once with the renewed token and uses it for later requests" do
    renew = instance_double(Proc)
    allow(renew).to receive(:call).with("old").and_return("new")
    stub_request(:get, url).with(headers: bearer("old")).to_return(unauthorized)
    stub_request(:get, url).with(headers: bearer("new")).to_return(ok)

    client = Kit::Client.new(access_token: "old", renew: renew)
    expect(client.account.get.account.id).to eq(2)
    client.account.get

    expect(renew).to have_received(:call).once
    expect(a_request(:get, url).with(headers: bearer("new"))).to have_been_made.twice
  end

  it "renews for a POST too (the 401 means nothing was applied)" do
    stub_request(:post, "https://api.kit.com/v4/tags").with(headers: bearer("old")).to_return(unauthorized)
    created = { status: 201, body: JSON.generate("tag" => { "id" => 9, "name" => "vip" }),
                headers: { "Content-Type" => "application/json" } }
    stub_request(:post, "https://api.kit.com/v4/tags").with(headers: bearer("new")).to_return(created)

    client = Kit::Client.new(access_token: "old", renew: ->(_current) { "new" })
    expect(client.tags.create(name: "vip").id).to eq(9)
  end

  it "raises the second 401 instead of renewing again" do
    calls = 0
    stub_request(:get, url).to_return(unauthorized)

    client = Kit::Client.new(access_token: "old", renew: ->(_) { "new#{calls += 1}" })
    expect { client.account.get }.to raise_error(Kit::AuthenticationError)
    expect(calls).to eq(1)
    expect(a_request(:get, url)).to have_been_made.twice
  end

  it "raises the original 401 when the callable returns nil (cannot renew)" do
    stub_request(:get, url).to_return(unauthorized)

    client = Kit::Client.new(access_token: "old", renew: ->(_) {})
    expect { client.account.get }.to raise_error(Kit::AuthenticationError, /401/)
    expect(a_request(:get, url)).to have_been_made.once
    expect(client.config.auth.access_token).to eq("old")
  end

  it "does not renew on a 403 (scope, not expiry)" do
    calls = 0
    stub_request(:get, url).to_return(status: 403, body: JSON.generate("errors" => ["Forbidden"]),
                                      headers: { "Content-Type" => "application/json" })

    client = Kit::Client.new(access_token: "old", renew: ->(_) { (calls += 1) && "new" })
    expect { client.account.get }.to raise_error(Kit::AuthorizationError)
    expect(calls).to eq(0)
    expect(a_request(:get, url)).to have_been_made.once
  end

  it "lets an error raised by the callable propagate untouched" do
    stub_request(:get, url).to_return(unauthorized)
    boom = Class.new(StandardError)

    client = Kit::Client.new(access_token: "old", renew: ->(_) { raise boom, "refresh failed" })
    expect { client.account.get }.to raise_error(boom, "refresh failed")
  end

  it "passes the token in use so the callable can adopt a pair another process persisted" do
    seen = nil
    stub_request(:get, url).with(headers: bearer("old")).to_return(unauthorized)
    stub_request(:get, url).with(headers: bearer("persisted")).to_return(ok)

    client = Kit::Client.new(access_token: "old", renew: ->(current) { (seen = current) && "persisted" })
    client.account.get
    expect(seen).to eq("old")
  end

  it "renews once per request even after a retried 429" do
    stub_request(:get, url).with(headers: bearer("old"))
                           .to_return({ status: 429, headers: { "Retry-After" => "1" } }, unauthorized)
    stub_request(:get, url).with(headers: bearer("new")).to_return(ok)

    config = Kit::Configuration.new(access_token: "old", renew: ->(_) { "new" }, max_retries: 1)
    connection = Kit::Connection.new(config)
    allow(connection).to receive(:backoff_sleep)
    expect(Kit::Resources::Account.new(connection).get.account.id).to eq(2)
  end

  describe "concurrency" do
    # A request sent with the old token is held until another thread has
    # renewed; its 401 must be attributed to the token it was sent with, and
    # since a newer one is already installed it retries with that — without
    # calling the callable a second time.
    it "retries with the token another thread installed instead of renewing again" do
      renew_calls = []
      other_renewed = Queue.new
      old_requests = 0
      stub_request(:get, url).with(headers: bearer("old")).to_return do
        old_requests += 1
        other_renewed.pop if old_requests == 1 # the first old-token request is held until the other thread renews
        unauthorized
      end
      stub_request(:get, url).with(headers: bearer("new")).to_return(ok)

      config = Kit::Configuration.new(access_token: "old", renew: ->(current) { (renew_calls << current) && "new" })
      held = Thread.new { Kit::Connection.new(config).request(:get, "/v4/account") }
      Thread.pass until held.status == "sleep" # held inside the stub, still holding "old"
      Kit::Connection.new(config).request(:get, "/v4/account") # 401s, renews, installs "new"
      other_renewed << true
      held.join

      expect(renew_calls).to eq(["old"])
      expect(config.auth.access_token).to eq("new")
      expect(a_request(:get, url).with(headers: bearer("new"))).to have_been_made.twice
    end

    # Two requests sent with the same old token both 401 and both call renew.
    # The one whose callable finishes last must not roll back the token the
    # first one installed.
    it "does not let a late renewal overwrite a newer token" do
      auth = Kit::Auth::OAuth.new("old")
      auth.replace("token-2")
      expect(auth.replace("token-1", if_current: "old")).to be(false)
      expect(auth.access_token).to eq("token-2")
      expect(auth.replace("token-3", if_current: "token-2")).to be(true)
      expect(auth.access_token).to eq("token-3")
    end

    it "retries with the newer token even when its own callable gave up (nil)" do
      first_call_may_return = Queue.new
      calls = 0
      renew = lambda do |_current|
        calls += 1
        if calls == 1
          first_call_may_return.pop # hold until the other thread has installed "new"
          nil                       # e.g. could not take the lock: give up
        else
          "new"
        end
      end
      stub_request(:get, url).with(headers: bearer("old")).to_return(unauthorized)
      stub_request(:get, url).with(headers: bearer("new")).to_return(ok)

      config = Kit::Configuration.new(access_token: "old", renew: renew)
      slow = Thread.new { Kit::Connection.new(config).request(:get, "/v4/account") }
      Thread.pass until slow.status == "sleep"
      Kit::Connection.new(config).request(:get, "/v4/account")
      first_call_may_return << true
      expect { slow.join }.not_to raise_error

      expect(calls).to eq(2)
      expect(a_request(:get, url).with(headers: bearer("new"))).to have_been_made.twice
    end

    it "retries with the newer token when its own renewal lost the race" do
      first_call_may_return = Queue.new
      results = []
      renew = lambda do |current|
        results << current
        if results.size == 1
          first_call_may_return.pop # hold until the second renewal has installed token-2
          "token-1"
        else
          "token-2"
        end
      end
      stub_request(:get, url).with(headers: bearer("old")).to_return(unauthorized)
      stub_request(:get, url).with(headers: bearer("token-1")).to_return(unauthorized) # stale: would 401 again
      stub_request(:get, url).with(headers: bearer("token-2")).to_return(ok)

      config = Kit::Configuration.new(access_token: "old", renew: renew)
      a = Kit::Connection.new(config)
      b = Kit::Connection.new(config)

      slow = Thread.new { a.request(:get, "/v4/account") }
      Thread.pass until slow.status == "sleep"                     # a is inside renew, holding
      b.request(:get, "/v4/account")                               # b renews to token-2 and succeeds
      expect(config.auth.access_token).to eq("token-2")
      first_call_may_return << true
      expect { slow.join }.not_to raise_error                      # a's token-1 is discarded; retries with token-2

      expect(results).to eq(%w[old old])
      expect(config.auth.access_token).to eq("token-2")
      expect(a_request(:get, url).with(headers: bearer("token-1"))).not_to have_been_made
    end
  end

  describe "configuration" do
    it "rejects renew: with an API key" do
      expect { Kit::Client.new(api_key: "k", renew: -> {}) }
        .to raise_error(Kit::ConfigurationError, /only meaningful with access_token/)
    end

    it "rejects a renew: that is not callable" do
      expect { Kit::Client.new(access_token: "t", renew: "nope") }
        .to raise_error(Kit::ConfigurationError, /respond to #call/)
    end

    it "rejects a blank replacement token from the callable" do
      stub_request(:get, url).to_return(unauthorized)
      client = Kit::Client.new(access_token: "old", renew: ->(_) { "" })
      expect { client.account.get }.to raise_error(Kit::ConfigurationError, /cannot be blank/)
    end
  end

  describe Kit::Auth::OAuth do
    it "masks the current token in inspect after a replace" do
      auth = described_class.new("original-token-value")
      auth.replace("renewed-token-value")
      expect(auth.inspect).to include("****alue")
      expect(auth.inspect).not_to include("renewed-token")
      expect(auth.headers).to eq("Authorization" => "Bearer renewed-token-value")
    end
  end
end
