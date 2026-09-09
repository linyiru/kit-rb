# frozen_string_literal: true

module Kit
  module Objects
    # The result of Subscribers#upsert_and_tag: the upserted Subscriber and the
    # Tags actually applied to it (one per distinct name, de-duplicated the way
    # Kit matches names), so a caller can count what happened.
    TaggedSubscriber = Data.define(:subscriber, :tags) do
      def tag_names
        tags.map(&:name)
      end
    end
  end
end
