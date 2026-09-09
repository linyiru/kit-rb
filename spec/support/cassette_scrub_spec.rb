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

  it "rewrites user.id and account.id regardless of key order or formatting" do
    body = "{ \"user\" : { \"email\" : \"ada@example.com\", \"id\" : 410676 },\n " \
           "\"account\" : { \"name\" : \"\", \"id\" : 379565 } }"
    json = JSON.parse(described_class.body(body))
    expect(json.dig("user", "id")).to eq(1)
    expect(json.dig("account", "id")).to eq(2)
    expect(json.dig("user", "email")).to eq("<EMAIL>")
  end

  it "does not invent ids, and leaves other ids alone" do
    no_id = JSON.parse(described_class.body('{"user":{"email":"ada@example.com"}}'))
    expect(no_id).to eq("user" => { "email" => "<EMAIL>" })
    expect(JSON.parse(described_class.body('{"tag":{"id":23217323}}'))).to eq("tag" => { "id" => 23_217_323 })
  end

  it "returns non-JSON, non-object and nil bodies unchanged apart from the pattern rewrites" do
    expect(described_class.body("not json ada@example.com")).to eq("not json <EMAIL>")
    expect(described_class.body("[1,2]")).to eq("[1,2]")
    expect(described_class.body("")).to eq("")
    expect(described_class.body(nil)).to be_nil
  end
end
