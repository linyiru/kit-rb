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
        one(:get, "/v4/snippets/#{path_id(id)}", "snippet", Objects::Snippet)
      end

      # POST /v4/snippets. An "inline" snippet carries Liquid text in
      # `content`; a "block" snippet carries HTML in
      # `document_attributes: { value_html: ... }`.
      def create(name:, snippet_type:, content: OMIT, document_attributes: OMIT)
        body = given(name: name, snippet_type: snippet_type, content: content,
                     document_attributes: document_attributes)
        one(:post, "/v4/snippets", "snippet", Objects::Snippet, body: body)
      end

      # PUT /v4/snippets/:id — rename, archive/restore, or replace the content
      # (snippet_type cannot change).
      def update(id, name: OMIT, archived: OMIT, content: OMIT, document_attributes: OMIT)
        body = given(name: name, archived: archived, content: content, document_attributes: document_attributes)
        one(:put, "/v4/snippets/#{path_id(id)}", "snippet", Objects::Snippet, body: body)
      end
    end
  end
end
