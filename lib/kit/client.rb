# frozen_string_literal: true

module Kit
  # The entry point. Construct with one credential, then reach resources:
  #
  #   client = Kit::Client.new(api_key: ENV.fetch("KIT_API_KEY"))
  #   client.account.get.account.plan_type
  #
  #   client = Kit::Client.new(access_token: oauth_token) # OAuth
  #
  # A client is thread-safe to share: it holds immutable config and a stateless
  # connection, and resource accessors are memoized per client. Tags is the one
  # resource with state (its ensure cache), so it is built eagerly here rather
  # than lazily: a lazy `||=` racing on first access could hand `subscribers`
  # and `client.tags` two different caches.
  class Client
    attr_reader :config, :tags

    def initialize(api_key: nil, access_token: nil, **options)
      @config = Configuration.new(api_key: api_key, access_token: access_token, **options)
      @connection = Connection.new(@config)
      @tags = Resources::Tags.new(@connection)
    end

    def account
      @account ||= Resources::Account.new(@connection)
    end

    def subscribers
      @subscribers ||= Resources::Subscribers.new(@connection, tags: tags)
    end

    def custom_fields
      @custom_fields ||= Resources::CustomFields.new(@connection)
    end

    def forms
      @forms ||= Resources::Forms.new(@connection)
    end

    def sequences
      @sequences ||= Resources::Sequences.new(@connection)
    end

    def broadcasts
      @broadcasts ||= Resources::Broadcasts.new(@connection)
    end

    def webhooks
      @webhooks ||= Resources::Webhooks.new(@connection)
    end

    def webhook_endpoints
      @webhook_endpoints ||= Resources::WebhookEndpoints.new(@connection)
    end

    def email_templates
      @email_templates ||= Resources::EmailTemplates.new(@connection)
    end

    def segments
      @segments ||= Resources::Segments.new(@connection)
    end

    def posts
      @posts ||= Resources::Posts.new(@connection)
    end

    def snippets
      @snippets ||= Resources::Snippets.new(@connection)
    end

    def purchases
      @purchases ||= Resources::Purchases.new(@connection)
    end

    def bulk
      @bulk ||= Resources::Bulk.new(@connection)
    end
  end
end
