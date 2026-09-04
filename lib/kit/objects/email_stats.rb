# frozen_string_literal: true

module Kit
  module Objects
    # Account-wide email engagement stats (/v4/account/email_stats), covering the
    # window [starting, ending].
    EmailStats = Data.define(
      :sent, :clicked, :opened, :email_stats_mode,
      :open_tracking_enabled, :click_tracking_enabled,
      :starting, :ending, :open_rate, :click_rate, :unsubscribe_rate, :bounce_rate
    ) do
      def self.from(hash)
        new(
          sent: hash["sent"], clicked: hash["clicked"], opened: hash["opened"],
          email_stats_mode: hash["email_stats_mode"],
          open_tracking_enabled: hash["open_tracking_enabled"],
          click_tracking_enabled: hash["click_tracking_enabled"],
          starting: hash["starting"], ending: hash["ending"],
          open_rate: hash["open_rate"], click_rate: hash["click_rate"],
          unsubscribe_rate: hash["unsubscribe_rate"], bounce_rate: hash["bounce_rate"]
        )
      end
    end
  end
end
