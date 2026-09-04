# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/snippets endpoints — reusable inline/document content.
    class Snippets < Base
      # GET /v4/snippets
      def list(**params)
        collection("/v4/snippets", "snippets", Objects::Snippet, params)
      end

      # GET /v4/snippets/:id
      def get(id)
        one(:get, "/v4/snippets/#{id}", "snippet", Objects::Snippet)
      end

      # POST /v4/snippets — pass name/snippet_type and content (inline) or
      # document (document); the API validates the combination.
      def create(**attributes)
        one(:post, "/v4/snippets", "snippet", Objects::Snippet, body: attributes)
      end

      # PUT /v4/snippets/:id
      def update(id, **attributes)
        one(:put, "/v4/snippets/#{id}", "snippet", Objects::Snippet, body: attributes)
      end
    end
  end
end
