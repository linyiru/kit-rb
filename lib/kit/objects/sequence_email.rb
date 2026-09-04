# frozen_string_literal: true

module Kit
  module Objects
    # An email within a sequence, as returned by
    # /v4/sequences/:sequence_id/emails. `position` is its order in the sequence;
    # `delay_value`/`delay_unit` set how long after the previous step it sends.
    SequenceEmail = Data.define(
      :id, :sequence_id, :subject, :preview_text, :email_address, :email_template_id,
      :published, :position, :delay_value, :delay_unit, :send_days, :stats
    ) do
      def self.from(hash)
        new(
          id: hash["id"], sequence_id: hash["sequence_id"], subject: hash["subject"],
          preview_text: hash["preview_text"], email_address: hash["email_address"],
          email_template_id: hash["email_template_id"], published: hash["published"],
          position: hash["position"], delay_value: hash["delay_value"],
          delay_unit: hash["delay_unit"], send_days: hash["send_days"], stats: hash["stats"]
        )
      end
    end
  end
end
