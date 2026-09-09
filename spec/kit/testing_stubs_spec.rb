# frozen_string_literal: true

require "kit/testing"

RSpec.describe Kit::Testing::Stubs do
  let(:testing) { Kit::Testing }
  let(:client) { Kit::Client.new(api_key: "k") }

  describe ".stub" do
    it "stubs a single-object operation with the documented body at its default status" do
      stub = testing.stub(:subscribers_create, id: 500, email_address: "ada@example.com")
      subscriber = client.subscribers.create(email_address: "ada@example.com")

      expect(subscriber).to have_attributes(id: 500, email_address: "ada@example.com", first_name: "Alice")
      expected = testing.attributes(:subscribers_create, id: 500, email_address: "ada@example.com")
      expect(subscriber).to eq(Kit::Objects::Subscriber.from(expected))
      expect(stub).to have_been_requested.once
    end

    it "substitutes named path params and matches any value for the ones not given" do
      exact = testing.stub(:tags_tag_subscriber, tag_id: 7, id: 500)
      client.tags.tag_subscriber(7, 500)
      expect(exact).to have_been_requested

      any_subscriber = testing.stub(:tags_tag_subscriber, tag_id: 8)
      client.tags.tag_subscriber(8, 1)
      client.tags.tag_subscriber(8, 2)
      expect(any_subscriber).to have_been_requested.twice
    end

    it "applies a path param that is also a response field to the body, so the answer carries the id asked for" do
      testing.stub(:subscribers_get, id: 500)
      expect(client.subscribers.get(500).id).to eq(500)

      testing.stub(:tags_update, id: 9, name: "renamed")
      expect(client.tags.update(9, name: "renamed")).to have_attributes(id: 9, name: "renamed")

      # tag_id is a path param only; id names both the path and the subscriber returned
      testing.stub(:tags_tag_subscriber, tag_id: 7, id: 500)
      expect(client.tags.tag_subscriber(7, 500).id).to eq(500)
    end

    it "serves the body Kit documents for the chosen http_status, not always the first one" do
      bulk = Kit::Client.new(access_token: "t").bulk
      testing.stub(:bulk_create_subscribers, http_status: 202)
      result = bulk.create_subscribers([{ email_address: "a@example.com" }])
      expect(result.async).to be(true)
      expect(result.items).to eq([])

      testing.stub(:bulk_create_subscribers) # 200: applied now, with items
      expect(bulk.create_subscribers([{ email_address: "a@example.com" }]).async).to be(false)
    end

    it "encodes path values exactly as the client does, and refuses a nil or blank one" do
      stub = testing.stub(:subscribers_get, id: "a b")
      client.subscribers.get("a b") # the client sends /a%20b
      expect(stub).to have_been_requested
      expect(testing.url_for(:subscribers_get, id: "1/unsubscribe?x")).to eq("https://api.kit.com/v4/subscribers/1%2Funsubscribe%3Fx")
      expect { testing.url_for(:subscribers_get, id: nil) }.to raise_error(ArgumentError, /id must not be nil or blank/)
      expect { testing.stub(:subscribers_get, id: " ") }.to raise_error(ArgumentError, /id must not be nil or blank/)
    end

    it "applies a path field shared with list rows (sequences_emails' sequence_id) to every row, not to pagination" do
      stub = testing.stub(:sequences_emails, sequence_id: 5, items: 2, has_next_page: true)
      page = client.sequences.emails(5)
      expect(stub).to have_been_requested
      expect(page.map(&:sequence_id)).to eq([5, 5])
      expect(page.size).to eq(2)
      expect(page.pagination.has_next_page).to be(true)

      testing.stub(:sequences_emails, sequence_id: 6, items: [{ subject: "a" }, { subject: "b", sequence_id: 99 }])
      # the path wins over a row's own value for the shared field: the response stays consistent with the URL
      expect(client.sequences.emails(6).map { |e| [e.sequence_id, e.subject] }).to eq([[6, "a"], [6, "b"]])
    end

    it "does not let a wildcard swallow a deeper path" do
      testing.stub(:subscribers_get) # /v4/subscribers/{id}
      # unstubbed: /v4/subscribers/1/tags
      expect do
        client.subscribers.tags(1)
      end.to raise_error(StandardError, %r{subscribers/1/tags})
    end

    it "matches a request with a query string" do
      stub = testing.stub(:subscribers_list, items: 2)
      expect(client.subscribers.list(status: "active", per_page: 10).size).to eq(2)
      expect(stub).to have_been_requested
    end

    it "shapes a list page with items: and the pagination keywords" do
      testing.stub(:tags_list, items: [{ name: "vip" }, { name: "beta" }], has_next_page: true, end_cursor: "E")
      page = client.tags.list
      expect(page.map(&:name)).to eq(%w[vip beta])
      expect(page.pagination.has_next_page).to be(true)
      expect(page.pagination.end_cursor).to eq("E")
    end

    it "picks among the documented statuses with http_status: and answers 204 operations with no body" do
      created = testing.stub(:tags_create, http_status: 201, name: "vip")
      expect(client.tags.create(name: "vip").name).to eq("vip")
      expect(created).to have_been_requested

      deleted = testing.stub(:custom_fields_delete, id: 3)
      expect(client.custom_fields.delete(3)).to be_nil
      expect(deleted).to have_been_requested
    end

    it "returns WebMock's stub so .with and have_been_requested chain as usual" do
      stub = testing.stub(:tags_create).with(body: { "name" => "vip" })
      client.tags.create(name: "vip")
      expect(stub).to have_been_requested.once
      expect { client.tags.create(name: "other") }.to raise_error(StandardError, %r{POST https://api\.kit\.com/v4/tags})
    end

    it "rejects a typo in an override, an unknown path param, an undocumented status and an unknown operation" do
      expect { testing.stub(:tags_create, nmae: "x") }.to raise_error(ArgumentError, /"nmae" is not a field of "tag"/)
      expect(testing.stub(:tags_create, id: 1)).to be_a(WebMock::RequestStub) # id is a tag field, not a path param here
      expect { testing.stub(:tags_create, http_status: 204) }.to raise_error(ArgumentError, /documents 200, 201/)
      expect { testing.stub(:tags_frobnicate) }.to raise_error(ArgumentError, /unknown Kit operation/)
    end
  end

  describe ".stub_error / .stub_rate_limited" do
    it "stubs Kit's error envelope at the given status, raising the typed error" do
      testing.stub_error(:account_get, 401, "The API key is invalid")
      expect { client.account.get }.to raise_error(Kit::AuthenticationError, /The API key is invalid/)

      testing.stub_error(:subscribers_get, 404, "Not found", id: 9)
      expect { client.subscribers.get(9) }.to raise_error(Kit::NotFoundError)
    end

    it "stubs a 429 with Retry-After that the client surfaces on RateLimitError" do
      testing.stub_rate_limited(:subscribers_create, retry_after: 7)
      client = Kit::Client.new(api_key: "k", max_retries: 0)
      expect { client.subscribers.create(email_address: "a@example.com") }
        .to raise_error(Kit::RateLimitError) { |e| expect(e.retry_after).to eq(7) }
    end
  end

  describe ".url_for" do
    it "is a String when every path param is given, else a Regexp usable with a_request" do
      expect(testing.url_for(:tags_tag_subscriber, tag_id: 7, id: 500)).to eq("https://api.kit.com/v4/tags/7/subscribers/500")
      expect(testing.url_for(:account_get)).to eq("https://api.kit.com/v4/account")
      pattern = testing.url_for(:subscribers_get)
      expect(pattern).to be_a(Regexp)
      expect(pattern).to match("https://api.kit.com/v4/subscribers/42")
      expect(pattern).not_to match("https://api.kit.com/v4/subscribers/42/tags")
      expect(pattern).not_to match("https://api.kit.com/v4/subscribers/42?x=1") # url_for is the bare URL

      testing.stub(:subscribers_get)
      client.subscribers.get(42)
      expect(a_request(:get, testing.url_for(:subscribers_get, id: 42))).to have_been_made
    end

    it "rejects a param that is not in the path" do
      expect do
        testing.url_for(:tags_create, id: 1)
      end.to raise_error(ArgumentError, %r{"id" is not a path param of /v4/tags})
    end
  end

  it "requires WebMock, with a clear error when it is not loaded" do
    script = 'require "kit/testing"; ' \
             "begin; Kit::Testing.stub(:account_get); rescue Kit::ConfigurationError => e; print e.message; end"
    output = IO.popen([RbConfig.ruby, "--disable-gems", "-Ilib", "-e", script], &:read)
    expect(output).to include("needs WebMock")
  end

  # The scenario from #14: a tag sync that took six hand-written stubs, then
  # the same sync on a renewed token, now reads as what happens.
  it "expresses the issue's adapter scenario in a few lines" do
    testing.stub(:subscribers_create, id: 500)
    testing.stub(:tags_create, id: 7, name: "vip")
    testing.stub(:tags_tag_subscriber, tag_id: 7, id: 500)

    result = client.subscribers.upsert_and_tag(email_address: "ada@example.com", tag_names: ["vip"])
    expect(result.subscriber.id).to eq(500)
    expect(result.tag_names).to eq(["vip"])

    # Renewed-token run: the first call 401s, the renew hook supplies a token, everything else is the same stubs.
    WebMock.reset!
    testing.stub_error(:subscribers_create, 401,
                       "The access token is invalid").with(headers: { "Authorization" => "Bearer old" })
    testing.stub(:subscribers_create, id: 500).with(headers: { "Authorization" => "Bearer new" })
    testing.stub(:tags_create, id: 7, name: "vip")
    testing.stub(:tags_tag_subscriber, tag_id: 7, id: 500)

    oauth = Kit::Client.new(access_token: "old", renew: ->(_) { "new" })
    expect(oauth.subscribers.upsert_and_tag(email_address: "ada@example.com",
                                            tag_names: ["vip"]).tag_names).to eq(["vip"])
  end
end
