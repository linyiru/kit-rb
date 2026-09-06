# frozen_string_literal: true

# A 2xx whose body is not what the resource expects must surface as a
# Kit::Error, not as a KeyError/NoMethodError from inside the resource.
RSpec.describe Kit::UnexpectedResponseError do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def stub_raw(method, path, body, status: 200, type: "application/json")
    stub_request(method, "https://api.kit.com#{path}")
      .to_return(status: status, body: body, headers: { "Content-Type" => type })
  end

  it "is a Kit::Error, so a blanket rescue still catches it" do
    expect(described_class.ancestors).to include(Kit::Error)
    expect(described_class.ancestors).not_to include(Kit::APIError)
  end

  it "names the missing envelope key on a single-object read" do
    stub_raw(:get, "/v4/subscribers/1", '{"foo":{}}')
    expect { client.subscribers.get(1) }.to raise_error(described_class) do |e|
      expect(e.message).to include('"subscriber"').and include('["foo"]')
      expect(e.body).to eq("foo" => {})
    end
  end

  it "names the missing envelope key on a list read" do
    stub_raw(:get, "/v4/tags", '{"pagination":{}}')
    expect { client.tags.list }.to raise_error(described_class, /"tags"/)
  end

  it "reports a missing pagination object" do
    stub_raw(:get, "/v4/tags", '{"tags":[]}')
    expect { client.tags.list }.to raise_error(described_class, /"pagination"/)
  end

  it "reports an empty 2xx body where an object was expected" do
    stub_raw(:get, "/v4/subscribers/1", "")
    expect { client.subscribers.get(1) }.to raise_error(described_class, /empty body/)
  end

  it "reports a non-JSON 2xx body" do
    stub_raw(:get, "/v4/subscribers/1", "<html>maintenance</html>", type: "text/html")
    expect { client.subscribers.get(1) }.to raise_error(described_class, /String body/)
  end

  it "covers the non-enveloped reads too" do
    stub_raw(:get, "/v4/account/colors", "{}")
    expect { client.account.colors }.to raise_error(described_class, /"colors"/)

    stub_raw(:get, "/v4/broadcasts/1/clicks", '{"broadcast":{}}')
    expect { client.broadcasts.clicks(1) }.to raise_error(described_class, /"clicks"/)
  end
end
