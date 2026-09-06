# frozen_string_literal: true

require "openssl"

RSpec.describe Kit::Webhooks::Signature do
  let(:secret) { "whsec_test_secret" }
  let(:payload) { JSON.generate("delivery_id" => 1, "events" => []) }
  let(:now) { 1_753_797_130 }

  def sign(body, key, timestamp)
    OpenSSL::HMAC.hexdigest("SHA256", key, "#{timestamp}.#{body}")
  end

  def header(timestamp, *sigs)
    "t=#{timestamp}," + sigs.map { |sig| "v1=#{sig}" }.join(",")
  end

  it "computes hex(HMAC-SHA256(secret, \"t.body\")) like Kit" do
    expect(described_class.compute(secret, now, payload)).to eq(sign(payload, secret, now))
  end

  it "accepts a correctly signed, fresh delivery" do
    signature_header = header(now, sign(payload, secret, now))
    expect(described_class.verify!(payload, signature_header, secret: secret, now: now)).to be(true)
    expect(described_class.verify?(payload, signature_header, secret: secret, now: now)).to be(true)
  end

  it "rejects a tampered body" do
    signature_header = header(now, sign(payload, secret, now))
    expect { described_class.verify!("#{payload} ", signature_header, secret: secret, now: now) }
      .to raise_error(Kit::Webhooks::SignatureError, /no v1 signature matched/)
  end

  it "rejects the wrong secret" do
    signature_header = header(now, sign(payload, "other", now))
    expect(described_class.verify?(payload, signature_header, secret: secret, now: now)).to be(false)
  end

  it "rejects a timestamp outside the tolerance, in either direction" do
    stale = header(now - 301, sign(payload, secret, now - 301))
    expect { described_class.verify!(payload, stale, secret: secret, now: now) }
      .to raise_error(Kit::Webhooks::SignatureError, /outside tolerance \(301s > 300s\)/)
    future = header(now + 400, sign(payload, secret, now + 400))
    expect(described_class.verify?(payload, future, secret: secret, now: now)).to be(false)
    expect(described_class.verify?(payload, future, secret: secret, now: now, tolerance: nil)).to be(true)
  end

  it "accepts either v1 during a secret rotation" do
    rotated = header(now, sign(payload, "whsec_new", now), sign(payload, secret, now))
    expect(described_class.verify?(payload, rotated, secret: secret, now: now)).to be(true)
    expect(described_class.verify?(payload, rotated, secret: "whsec_new", now: now)).to be(true)
  end

  it "accepts an Array of secrets on the receiving side of a rotation" do
    signature_header = header(now, sign(payload, "whsec_new", now))
    expect(described_class.verify?(payload, signature_header, secret: [secret, "whsec_new"], now: now)).to be(true)
  end

  it "rejects a missing or malformed header with a specific error" do
    expect { described_class.verify!(payload, nil, secret: secret) }
      .to raise_error(Kit::Webhooks::SignatureError, /missing X-Kit-Signature/)
    expect { described_class.verify!(payload, "v1=abc", secret: secret) }
      .to raise_error(Kit::Webhooks::SignatureError, /malformed/)
    expect { described_class.verify!(payload, "t=soon,v1=abc", secret: secret) }
      .to raise_error(Kit::Webhooks::SignatureError, /malformed timestamp/)
  end

  it "requires a secret" do
    expect { described_class.verify!(payload, header(now, "x"), secret: "", now: now) }
      .to raise_error(ArgumentError, /secret/)
  end

  it "is a Kit::Error so a blanket rescue catches it" do
    expect(Kit::Webhooks::SignatureError.ancestors).to include(Kit::Error)
  end
end
