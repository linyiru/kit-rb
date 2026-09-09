# frozen_string_literal: true

# Kit::TagNames is the single place the client and Kit::Testing agree on how
# Kit matches tag names; Resources::Tags and Subscribers delegate to it.
RSpec.describe Kit::TagNames do
  it "is what Resources::Tags.normalize_name / .name_key delegate to" do
    expect(Kit::Resources::Tags.normalize_name(" a\u3000b ")).to eq(described_class.normalize(" a\u3000b "))
    expect(Kit::Resources::Tags.name_key("VIP")).to eq(described_class.key("VIP"))
  end

  it "de-duplicates case-insensitively with the first spelling winning" do
    expect(described_class.distinct(["VIP", "vip", " Vip ", "beta"])).to eq(%w[VIP beta])
    expect(described_class.distinct(nil)).to eq([])
    expect(described_class.distinct("solo")).to eq(["solo"])
  end

  it "rejects a blank name" do
    expect { described_class.distinct(["ok", " "]) }.to raise_error(ArgumentError, /blank/)
  end
end
