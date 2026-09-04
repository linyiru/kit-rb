# frozen_string_literal: true

module Kit
  module Objects
    # A sequence (formerly "course") as returned by /v4/sequences. Only id, name,
    # hold, repeat, and created_at are always present; the scheduling fields and
    # counts appear on full reads, and `stats` only when the request includes it.
    Sequence = Data.define(
      :id, :name, :hold, :repeat, :created_at, :updated_at,
      :email_address, :email_template_id, :send_days, :send_hour, :time_zone,
      :active, :exclude_subscriber_sources, :email_count, :subscriber_count, :stats
    ) do
      def self.from(hash)
        new(
          id: hash["id"], name: hash["name"], hold: hash["hold"], repeat: hash["repeat"],
          created_at: hash["created_at"], updated_at: hash["updated_at"],
          email_address: hash["email_address"], email_template_id: hash["email_template_id"],
          send_days: hash["send_days"], send_hour: hash["send_hour"], time_zone: hash["time_zone"],
          active: hash["active"], exclude_subscriber_sources: hash["exclude_subscriber_sources"],
          email_count: hash["email_count"], subscriber_count: hash["subscriber_count"],
          stats: hash["stats"]
        )
      end
    end
  end
end
