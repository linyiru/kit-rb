# frozen_string_literal: true

module Kit
  module Objects
    # Account subscriber-growth stats (/v4/account/growth_stats) over the window
    # [starting, ending].
    GrowthStats = Data.define(
      :cancellations, :net_new_subscribers, :new_subscribers, :subscribers,
      :starting, :ending
    ) do
      def self.from(hash)
        new(
          cancellations: hash["cancellations"], net_new_subscribers: hash["net_new_subscribers"],
          new_subscribers: hash["new_subscribers"], subscribers: hash["subscribers"],
          starting: hash["starting"], ending: hash["ending"]
        )
      end
    end
  end
end
