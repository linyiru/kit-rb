# frozen_string_literal: true

RSpec.describe CassetteScrub do
  it "rewrites every email, the creator subdomain URL with its form uid, sender names and uid fields" do
    body = '{"a":"one@x.io","b":"two@y.org","embed_js":"https://imoney.kit.com/10d511a4df/index.js",' \
           '"sending_addresses":[{"from_name":"Brand \\"quoted\\" name"}],"uid":"10d511a4df"}'
    out = described_class.body(body)
    expect(out).not_to include("one@x.io", "two@y.org", "imoney", "10d511a4df", "Brand")
    expect(JSON.parse(out)).to include(
      "embed_js" => "https://<SUBDOMAIN>.kit.com/<FORM_UID>/index.js", "uid" => "<FORM_UID>",
      "sending_addresses" => [{ "from_name" => "<FROM_NAME>" }]
    )
  end

  it "leaves the API host alone" do
    expect(described_class.body('{"u":"https://api.kit.com/v4/tags/1"}')).to include("https://api.kit.com/v4/tags/1")
  end

  it "returns non-JSON and nil bodies unchanged apart from the pattern rewrites" do
    expect(described_class.body("not json ada@example.com")).to eq("not json <EMAIL>")
    expect(described_class.body("")).to eq("")
    expect(described_class.body(nil)).to be_nil
  end
end
