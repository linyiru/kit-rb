# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/custom_fields endpoints.
    class CustomFields < Base
      # GET /v4/custom_fields
      def list(**params)
        collection("/v4/custom_fields", "custom_fields", Objects::CustomField, params)
      end

      # POST /v4/custom_fields
      def create(label:)
        object = http_post("/v4/custom_fields", body: { label: label }).fetch("custom_field")
        Objects::CustomField.from(object)
      end

      # PUT /v4/custom_fields/:id
      def update(id, label:)
        object = http_put("/v4/custom_fields/#{id}", body: { label: label }).fetch("custom_field")
        Objects::CustomField.from(object)
      end

      # DELETE /v4/custom_fields/:id
      def delete(id)
        http_delete("/v4/custom_fields/#{id}")
        nil
      end
    end
  end
end
