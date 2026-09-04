# frozen_string_literal: true

module Kit
  module Objects
    # Identity "object" for endpoints that return plain analytics hashes rather
    # than a modelled resource (e.g. the broadcast-stats list). Lets those lists
    # flow through Base#collection unchanged while keeping .from uniform.
    module Raw
      def self.from(hash) = hash
    end
  end
end
