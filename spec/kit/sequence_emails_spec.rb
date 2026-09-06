# frozen_string_literal: true

RSpec.describe "Kit::Resources::Sequences email management" do
  let(:client) { Kit::Client.new(api_key: "secret") }

  def email(id:, subject: "Day 1")
    { "id" => id, "sequence_id" => 5, "subject" => subject, "preview_text" => "",
      "email_address" => "creator@x.com", "email_template_id" => nil, "published" => true,
      "position" => 1, "delay_value" => 0, "delay_unit" => "day", "send_days" => nil, "stats" => {} }
  end

  def page(emails)
    { "emails" => emails,
      "pagination" => { "has_previous_page" => false, "has_next_page" => false,
                        "start_cursor" => "S", "end_cursor" => "E", "per_page" => 2 } }
  end

  describe "#emails" do
    it "returns a Collection of typed SequenceEmail" do
      stub_kit(:get, "/v4/sequences/5/emails", body: page([email(id: 1), email(id: 2)]))
      list = client.sequences.emails(5)
      expect(list.first).to be_a(Kit::Objects::SequenceEmail)
      expect(list.map(&:position)).to eq([1, 1])
    end
  end

  describe "#email" do
    it "fetches one sequence email" do
      stub_kit(:get, "/v4/sequences/5/emails/7", body: { "email" => email(id: 7) })
      expect(client.sequences.email(5, 7).id).to eq(7)
    end

    it "sends include=stats when asked" do
      stub = stub_request(:get, "https://api.kit.com/v4/sequences/5/emails/7")
             .with(query: { "include" => "stats" })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("email" => email(id: 7)))
      client.sequences.email(5, 7, include: "stats")
      expect(stub).to have_been_requested
    end
  end

  describe "#create_email" do
    it "posts the email and returns it" do
      stub = stub_request(:post, "https://api.kit.com/v4/sequences/5/emails")
             .with(body: { "subject" => "Welcome", "delay_value" => 0, "delay_unit" => "day" })
             .to_return(status: 201, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("email" => email(id: 9, subject: "Welcome")))
      result = client.sequences.create_email(5, subject: "Welcome", delay_value: 0, delay_unit: "day")
      expect(result).to be_a(Kit::Objects::SequenceEmail)
      expect(stub).to have_been_requested
    end
  end

  describe "#update_email" do
    it "puts changed attributes" do
      stub_kit(:put, "/v4/sequences/5/emails/9", body: { "email" => email(id: 9, subject: "Edited") })
      expect(client.sequences.update_email(5, 9, subject: "Edited").subject).to eq("Edited")
    end

    it "sends an explicit nil to clear a field, but omits fields not passed" do
      stub = stub_request(:put, "https://api.kit.com/v4/sequences/5/emails/9")
             .with(body: { "send_days" => nil })
             .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                        body: JSON.generate("email" => email(id: 9)))
      client.sequences.update_email(5, 9, send_days: nil)
      expect(stub).to have_been_requested
    end

    it "rejects a field the API does not document" do
      expect { client.sequences.update_email(5, 9, subjekt: "typo") }.to raise_error(ArgumentError, /subjekt/)
    end
  end

  describe "#delete_email" do
    it "deletes the email and returns nil" do
      stub = stub_kit(:delete, "/v4/sequences/5/emails/9", status: 204, body: "")
      expect(client.sequences.delete_email(5, 9)).to be_nil
      expect(stub).to have_been_requested
    end
  end
end
