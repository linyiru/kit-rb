# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/email_templates endpoints.
    class EmailTemplates < Base
      # GET /v4/email_templates
      def list(**params)
        collection("/v4/email_templates", "email_templates", Objects::EmailTemplate, params)
      end
    end
  end
end
