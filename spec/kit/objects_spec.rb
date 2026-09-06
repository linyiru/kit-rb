# frozen_string_literal: true

# Value objects against the response shapes the OpenAPI document declares:
# every documented field is readable, and absent fields read as nil rather
# than raising, since most appear only in one endpoint's context.
RSpec.describe "Kit::Objects response fields" do
  describe Kit::Objects::Account do
    it "types timezone, plan, and sending_addresses" do
      account = described_class.from(
        "id" => 1, "name" => "Acme", "plan_type" => "creator", "primary_email_address" => "a@x.com",
        "created_at" => "2026-01-01T00:00:00Z",
        "timezone" => { "name" => "Asia/Taipei", "friendly_name" => "Taipei", "utc_offset" => "+08:00" },
        "plan" => { "plan_type" => "creator", "interval" => "month", "subscriber_limit" => 10_000,
                    "on_trial" => false, "trial_lapse_date" => nil, "renews_at" => "2026-10-01", "cancels_at" => nil },
        "sending_addresses" => [{ "email_address" => "hi@x.com", "from_name" => "Acme", "status" => "verified",
                                  "is_default" => true, "is_verified" => true, "is_dmarc_configured" => false }]
      )
      expect(account.timezone).to be_a(Kit::Objects::Timezone)
      expect(account.timezone.utc_offset).to eq("+08:00")
      expect(account.plan).to be_a(Kit::Objects::Plan)
      expect(account.plan.subscriber_limit).to eq(10_000)
      expect(account.sending_addresses.first).to be_a(Kit::Objects::SendingAddress)
      expect(account.sending_addresses.first).to have_attributes(is_default: true, from_name: "Acme")
    end

    it "reads nil sub-objects and an empty address list when absent" do
      account = described_class.from("id" => 1)
      expect(account.timezone).to be_nil
      expect(account.plan).to be_nil
      expect(account.sending_addresses).to eq([])
    end
  end

  it "reads Post#content and SequenceEmail#content, nil when not included" do
    expect(Kit::Objects::Post.from("id" => 1, "content" => "<p>hi</p>").content).to eq("<p>hi</p>")
    expect(Kit::Objects::Post.from("id" => 1).content).to be_nil
    expect(Kit::Objects::SequenceEmail.from("id" => 1, "content" => "<p>day 1</p>").content).to eq("<p>day 1</p>")
    expect(Kit::Objects::SequenceEmail.from("id" => 1).content).to be_nil
  end

  it "reads Tag#tagged_at and CustomField#created_at" do
    expect(Kit::Objects::Tag.from("id" => 1, "name" => "vip", "tagged_at" => "2026-02-02T00:00:00Z").tagged_at)
      .to eq("2026-02-02T00:00:00Z")
    expect(Kit::Objects::Tag.from("id" => 1, "name" => "vip").tagged_at).to be_nil
    expect(Kit::Objects::CustomField.from("id" => 1, "created_at" => "2026-02-02T00:00:00Z").created_at)
      .to eq("2026-02-02T00:00:00Z")
  end

  describe Kit::Objects::Subscriber do
    it "reads the per-endpoint context fields" do
      subscriber = described_class.from(
        "id" => 1, "email_address" => "s@x.com", "added_at" => "2026-01-01T00:00:00Z",
        "tagged_at" => "2026-01-02T00:00:00Z", "referrer" => "https://ref.example",
        "referrer_utm_parameters" => { "source" => "newsletter" },
        "attribution" => { "utm_source" => "x", "source_type" => "form" },
        "tags" => [{ "id" => 3, "name" => "vip" }], "tag_names" => ["vip"], "tag_ids" => [3],
        "stats" => { "sent" => 10 }
      )
      expect(subscriber).to have_attributes(
        added_at: "2026-01-01T00:00:00Z", tagged_at: "2026-01-02T00:00:00Z", referrer: "https://ref.example",
        referrer_utm_parameters: { "source" => "newsletter" }, tag_names: ["vip"], tag_ids: [3]
      )
      expect(subscriber.attribution["source_type"]).to eq("form")
      expect(subscriber.tags.first["name"]).to eq("vip")
      expect(subscriber.stats["sent"]).to eq(10)
    end

    it "reads nil for context fields the endpoint did not supply" do
      subscriber = described_class.from("id" => 1)
      expect(subscriber).to have_attributes(added_at: nil, tagged_at: nil, attribution: nil, tags: nil, stats: nil)
    end
  end
end
