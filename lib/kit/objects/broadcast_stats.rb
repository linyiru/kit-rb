# frozen_string_literal: true

module Kit
  module Objects
    # Performance stats for a broadcast, as returned by /v4/broadcasts/:id/stats
    # and each row of /v4/broadcasts/stats. The API nests the metrics under a
    # "stats" key alongside id/subject/send_at; this flattens them into one
    # object (subject/send_at are absent on the single-broadcast endpoint).
    BroadcastStats = Data.define(
      :id, :subject, :send_at, :recipients, :open_rate, :emails_opened,
      :click_rate, :unsubscribe_rate, :unsubscribes, :total_clicks,
      :show_total_clicks, :status, :progress, :open_tracking_disabled,
      :click_tracking_disabled
    ) do
      def self.from(hash)
        stats = hash["stats"] || {}
        new(
          id: hash["id"], subject: hash["subject"], send_at: hash["send_at"],
          recipients: stats["recipients"], open_rate: stats["open_rate"],
          emails_opened: stats["emails_opened"], click_rate: stats["click_rate"],
          unsubscribe_rate: stats["unsubscribe_rate"], unsubscribes: stats["unsubscribes"],
          total_clicks: stats["total_clicks"], show_total_clicks: stats["show_total_clicks"],
          status: stats["status"], progress: stats["progress"],
          open_tracking_disabled: stats["open_tracking_disabled"],
          click_tracking_disabled: stats["click_tracking_disabled"]
        )
      end
    end
  end
end
