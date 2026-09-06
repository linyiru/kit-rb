# frozen_string_literal: true

RSpec.describe Kit::Webhooks::Events do
  it "lists every documented event type exactly once, with its data keys" do
    expect(described_class::ALL.size).to eq(28)
    expect(described_class::ALL.uniq).to eq(described_class::ALL)
    expect(described_class::ALL).to all(match(/\A[a-z_]+\.[a-z_]+\z/))
    expect(described_class::DATA_KEYS.fetch("subscriber.tag_added")).to eq(%w[subscriber tag])
  end

  it "separates planned events from available ones" do
    expect(described_class::PLANNED).to include("subscriber.link_clicked", "landing_page.created")
    expect(described_class::AVAILABLE).to include("subscriber.created", "broadcast.sent")
    expect(described_class::AVAILABLE & described_class::PLANNED).to be_empty
    expect(described_class::AVAILABLE + described_class::PLANNED).to match_array(described_class::ALL)
  end

  it "names constants after the event strings" do
    expect(described_class::SUBSCRIBER_CUSTOM_FIELD_VALUE_UPDATED).to eq("subscriber.custom_field_value_updated")
    expect(described_class::POST_PUBLISHED).to eq("post.published")
  end
end

RSpec.describe Kit::Webhooks::LegacyEvents do
  it "lists the 15 previous-generation event names" do
    expect(described_class::ALL.size).to eq(15)
    expect(described_class::ALL).to include("subscriber.subscriber_activate", "purchase.purchase_create")
  end

  it "knows which extra parameter a scoped legacy event needs" do
    expect(described_class::REQUIRED_PARAM.fetch("subscriber.tag_add")).to eq(:tag_id)
    expect(described_class::REQUIRED_PARAM.fetch("subscriber.link_click")).to eq(:initiator_value)
    expect(described_class::REQUIRED_PARAM.keys).to all(satisfy { |name| described_class::ALL.include?(name) })
    expect(described_class::REQUIRED_PARAM).not_to have_key("subscriber.subscriber_activate")
  end
end
