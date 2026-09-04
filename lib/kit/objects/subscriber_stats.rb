# frozen_string_literal: true

module Kit
  module Objects
    # Engagement stats for a subscriber (/v4/subscribers/:id/stats). The API
    # nests the metrics under "stats" next to the id; this flattens them.
    SubscriberStats = Data.define(
      :id, :sent, :opened, :clicked, :bounced, :open_rate, :click_rate,
      :last_sent, :last_opened, :last_clicked,
      :sends_since_last_open, :sends_since_last_click
    ) do
      def self.from(hash)
        stats = hash["stats"] || {}
        new(
          id: hash["id"], sent: stats["sent"], opened: stats["opened"],
          clicked: stats["clicked"], bounced: stats["bounced"],
          open_rate: stats["open_rate"], click_rate: stats["click_rate"],
          last_sent: stats["last_sent"], last_opened: stats["last_opened"],
          last_clicked: stats["last_clicked"],
          sends_since_last_open: stats["sends_since_last_open"],
          sends_since_last_click: stats["sends_since_last_click"]
        )
      end
    end
  end
end
