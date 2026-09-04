# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/posts endpoints — broadcasts published to the web.
    class Posts < Base
      # GET /v4/posts
      def list(**params)
        collection("/v4/posts", "posts", Objects::Post, params)
      end

      # GET /v4/posts/:id
      def get(id)
        one(:get, "/v4/posts/#{id}", "post", Objects::Post)
      end
    end
  end
end
