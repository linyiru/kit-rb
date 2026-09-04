# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/segments endpoints.
    class Segments < Base
      # GET /v4/segments
      def list(**params)
        collection("/v4/segments", "segments", Objects::Segment, params)
      end
    end
  end
end
