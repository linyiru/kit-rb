# frozen_string_literal: true

require "kit/testing"

RSpec.describe Kit::Testing::Factories do
  let(:testing) { Kit::Testing }

  it "defines one typed factory per envelope builder, parsed by the class the resource uses" do
    testing::Factories::OBJECT_CLASSES.each do |factory, klass|
      value = testing.public_send(factory)
      expect(value).to be_a(klass), factory
      expect(testing.public_send(factory, id: 77).id).to eq(77), factory if klass.members.include?(:id)
    end
    expect(testing::Factories::OBJECT_CLASSES.keys).to match_array(testing::OBJECTS.keys)
  end

  it "applies overrides with the same field validation as the envelope builders" do
    subscriber = testing.subscriber(id: 500, email_address: "ada@example.com", first_name: "Ada")
    expect(subscriber).to have_attributes(id: 500, email_address: "ada@example.com", first_name: "Ada", state: "active")
    expect { testing.subscriber(emial: "x") }.to raise_error(ArgumentError, /"emial" is not a field of "subscriber"/)
    expect { testing.email_stats(net_new_subscribers: 1) }.to raise_error(ArgumentError, /not a field of "email_stats"/)
  end

  it "equals what the client parses from the matching envelope builder" do
    stub_request(:get, "https://api.kit.com/v4/subscribers/500")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                 body: JSON.generate(testing.subscriber_json(id: 500)))
    expect(Kit::Client.new(api_key: "k").subscribers.get(500)).to eq(testing.subscriber(id: 500))
  end

  it "reads nested stats through the object's own accessors" do
    expect(testing.broadcast_stats(stats: { "recipients" => 9 }).recipients).to eq(9)
    expect(testing.subscriber_stats.sent).to be_an(Integer)
  end

  it "rejects an unknown factory name" do
    expect { testing.object(:frobnicator) }.to raise_error(ArgumentError, /unknown Kit::Testing factory :frobnicator/)
  end

  describe ".account_info" do
    it "builds the whole GET /v4/account result with account and user overrides" do
      info = testing.account_info(plan_type: "free", name: "", user: { email: "owner@example.com" })
      expect(info).to be_a(Kit::Objects::AccountInfo)
      expect(info.account).to have_attributes(plan_type: "free", name: "")
      expect(info.account.plan).to be_a(Kit::Objects::Plan)
      expect(info.user.email).to eq("owner@example.com")
    end

    it "rejects an unknown user field instead of silently dropping it" do
      expect { testing.account_info(user: { emial: "x" }) }
        .to raise_error(ArgumentError, /"emial" is not a field of "user"; known: email, id/)
    end

    it "matches what the client parses from account_json" do
      stub_request(:get, "https://api.kit.com/v4/account")
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: JSON.generate(testing.account_json(plan_type: "free")))
      expect(Kit::Client.new(api_key: "k").account.get).to eq(testing.account_info(plan_type: "free"))
    end
  end

  describe ".oauth_token" do
    it "builds a Kit::OAuth::Token whose expiry helpers work" do
      token = testing.oauth_token(created_at: 1_000)
      expect(token).to be_a(Kit::OAuth::Token)
      expect(token.expires_in).to eq(172_800)
      expect(token.expires_at).to eq(173_800)
      expect(token.expired?(now: 1_000)).to be(false)
      expect(token.expiring_within?(200_000, now: 1_000)).to be(true)
      expect(token.refresh_token).to eq("<REFRESH_TOKEN>")
    end

    it "accepts only token fields and never puts a real-looking secret in inspect" do
      expect { testing.oauth_token(exp: 1) }.to raise_error(ArgumentError, /"exp" is not a field of "token"/)
      token = testing.oauth_token(access_token: "supersecrettoken1234")
      expect(token.inspect).not_to include("supersecrettoken")
    end
  end

  describe ".tagged_subscriber" do
    it "builds Subscribers#upsert_and_tag's result with one Tag per name" do
      result = testing.tagged_subscriber(tag_names: %w[vip beta], email_address: "ada@example.com")
      expect(result).to be_a(Kit::Objects::TaggedSubscriber)
      expect(result.subscriber.email_address).to eq("ada@example.com")
      expect(result.tag_names).to eq(%w[vip beta])
      expect(result.tags.map(&:id).uniq.size).to eq(2)
      expect(result.tags).to all(be_a(Kit::Objects::Tag))
    end

    it "defaults to one tag" do
      expect(testing.tagged_subscriber.tags.size).to eq(1)
    end

    it "normalises and de-duplicates names exactly as Subscribers#upsert_and_tag does" do
      names = ["VIP customer", "vip  CUSTOMER", " VIP\u3000customer ", "beta"]
      result = testing.tagged_subscriber(tag_names: names)
      expect(result.tag_names).to eq(["VIP customer", "beta"])
      expect(result.tags.map(&:id)).to eq(result.tags.map(&:id).uniq)

      # The same names through the real client apply the same two tags.
      json = { "Content-Type" => "application/json" }
      respond = ->(body) { { status: 200, headers: json, body: JSON.generate(body) } }
      stub_request(:post, "https://api.kit.com/v4/subscribers").to_return(respond.call(testing.subscriber_json(id: 1)))
      { "VIP customer" => 26, "beta" => 27 }.each do |name, id|
        stub_request(:post, "https://api.kit.com/v4/tags").with(body: { "name" => name })
                                                          .to_return(respond.call(testing.tag_json(id: id,
                                                                                                   name: name)))
      end
      stub_request(:post, %r{/v4/tags/2[67]/subscribers/1}).to_return(respond.call(testing.subscriber_json(id: 1)))
      live = Kit::Client.new(api_key: "k").subscribers.upsert_and_tag(email_address: "a@example.com", tag_names: names)
      expect(live.tag_names).to eq(result.tag_names)
    end
  end

  it "loads standalone without http.rb" do
    output = IO.popen([RbConfig.ruby, "--disable-gems", "-Ilib", "-e",
                       'require "kit/testing"; print Kit::Testing.subscriber(id: 5).id'], &:read)
    expect(output).to eq("5")
  end

  it "does not define the factories on require \"kit-rb\" alone" do
    output = IO.popen([RbConfig.ruby, "-Ilib", "-e", 'require "kit-rb"; print Kit.const_defined?(:Testing)'], &:read)
    expect(output).to eq("false")
  end
end
