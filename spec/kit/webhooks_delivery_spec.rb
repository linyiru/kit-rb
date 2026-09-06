# frozen_string_literal: true

require "openssl"

RSpec.describe Kit::Webhooks::Delivery do
  let(:secret) { "whsec_test" }
  let(:now) { 1_753_797_130 }
  let(:body) do
    JSON.generate(
      "delivery_id" => 123_456,
      "events" => [{ "id" => "9c2e1f3a-6b7d-4e8f-a1b2-c3d4e5f60718", "type" => "subscriber.created",
                     "created" => "2026-07-29T14:32:10Z",
                     "data" => { "subscriber" => { "id" => 987_654, "email_address" => "ada@example.com" } } }]
    )
  end
  let(:signature) { "t=#{now},v1=#{OpenSSL::HMAC.hexdigest("SHA256", secret, "#{now}.#{body}")}" }

  it "parses the documented envelope into typed events" do
    delivery = described_class.parse(body)
    expect(delivery.delivery_id).to eq(123_456)
    expect(delivery.type).to eq("subscriber.created")
    event = delivery.events.first
    expect(event).to be_a(Kit::Webhooks::Event)
    expect(event.id).to eq("9c2e1f3a-6b7d-4e8f-a1b2-c3d4e5f60718")
    expect(event.data.dig("subscriber", "email_address")).to eq("ada@example.com")
  end

  it "from_request verifies the signature before parsing" do
    delivery = described_class.from_request(body, signature, secret: secret, now: now)
    expect(delivery.events.size).to eq(1)

    expect { described_class.from_request(body, "t=#{now},v1=bad", secret: secret, now: now) }
      .to raise_error(Kit::Webhooks::SignatureError)
  end

  it "raises UnexpectedResponseError on a non-JSON or non-object body" do
    expect { described_class.parse("not json") }.to raise_error(Kit::UnexpectedResponseError, /not valid JSON/)
    expect { described_class.parse("[]") }.to raise_error(Kit::UnexpectedResponseError, /not a JSON object/)
  end

  it "tolerates an empty events array" do
    delivery = described_class.parse(JSON.generate("delivery_id" => 1))
    expect(delivery.events).to eq([])
    expect(delivery.type).to be_nil
  end
end
