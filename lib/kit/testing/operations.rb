# frozen_string_literal: true

module Kit
  module Testing
    # Every Kit v4 operation this gem drives, named `<resource>_<method>` after
    # the client method that calls it (`client.subscribers.create` is
    # :subscribers_create). Paths keep the OpenAPI `{placeholder}` form so the
    # registry can be checked one-to-one against the vendored contract; the
    # stub helpers substitute the placeholders.
    #
    # This is the single hand-written source: fixtures.json (example responses)
    # is generated from it plus the OpenAPI document, and a contract test fails
    # when either drifts from the other.
    OPERATIONS = {
      account_get: [:get, "/v4/account"],
      account_colors: [:get, "/v4/account/colors"],
      account_update_colors: [:put, "/v4/account/colors"],
      account_creator_profile: [:get, "/v4/account/creator_profile"],
      account_email_stats: [:get, "/v4/account/email_stats"],
      account_growth_stats: [:get, "/v4/account/growth_stats"],

      subscribers_list: [:get, "/v4/subscribers"],
      subscribers_create: [:post, "/v4/subscribers"],
      subscribers_filter: [:post, "/v4/subscribers/filter"],
      subscribers_get: [:get, "/v4/subscribers/{id}"],
      subscribers_update: [:put, "/v4/subscribers/{id}"],
      subscribers_unsubscribe: [:post, "/v4/subscribers/{id}/unsubscribe"],
      subscribers_tags: [:get, "/v4/subscribers/{subscriber_id}/tags"],
      subscribers_stats: [:get, "/v4/subscribers/{subscriber_id}/stats"],
      subscribers_set_location: [:post, "/v4/subscribers/{subscriber_id}/location"],
      subscribers_update_location: [:patch, "/v4/subscribers/{subscriber_id}/location"],
      subscribers_remove_location: [:delete, "/v4/subscribers/{subscriber_id}/location"],

      tags_list: [:get, "/v4/tags"],
      tags_create: [:post, "/v4/tags"],
      tags_update: [:put, "/v4/tags/{id}"],
      tags_subscribers: [:get, "/v4/tags/{tag_id}/subscribers"],
      tags_tag_subscriber: [:post, "/v4/tags/{tag_id}/subscribers/{id}"],
      tags_remove_subscriber: [:delete, "/v4/tags/{tag_id}/subscribers/{id}"],
      tags_tag_subscriber_by_email: [:post, "/v4/tags/{tag_id}/subscribers"],
      tags_remove_subscriber_by_email: [:delete, "/v4/tags/{tag_id}/subscribers"],

      custom_fields_list: [:get, "/v4/custom_fields"],
      custom_fields_create: [:post, "/v4/custom_fields"],
      custom_fields_update: [:put, "/v4/custom_fields/{id}"],
      custom_fields_delete: [:delete, "/v4/custom_fields/{id}"],

      forms_list: [:get, "/v4/forms"],
      forms_subscribers: [:get, "/v4/forms/{form_id}/subscribers"],
      forms_add_subscriber: [:post, "/v4/forms/{form_id}/subscribers/{id}"],
      forms_add_subscriber_by_email: [:post, "/v4/forms/{form_id}/subscribers"],

      sequences_list: [:get, "/v4/sequences"],
      sequences_create: [:post, "/v4/sequences"],
      sequences_get: [:get, "/v4/sequences/{id}"],
      sequences_update: [:put, "/v4/sequences/{id}"],
      sequences_delete: [:delete, "/v4/sequences/{id}"],
      sequences_subscribers: [:get, "/v4/sequences/{sequence_id}/subscribers"],
      sequences_add_subscriber: [:post, "/v4/sequences/{sequence_id}/subscribers/{id}"],
      sequences_add_subscriber_by_email: [:post, "/v4/sequences/{sequence_id}/subscribers"],
      sequences_emails: [:get, "/v4/sequences/{sequence_id}/emails"],
      sequences_create_email: [:post, "/v4/sequences/{sequence_id}/emails"],
      sequences_email: [:get, "/v4/sequences/{sequence_id}/emails/{id}"],
      sequences_update_email: [:put, "/v4/sequences/{sequence_id}/emails/{id}"],
      sequences_delete_email: [:delete, "/v4/sequences/{sequence_id}/emails/{id}"],

      broadcasts_list: [:get, "/v4/broadcasts"],
      broadcasts_create: [:post, "/v4/broadcasts"],
      broadcasts_get: [:get, "/v4/broadcasts/{id}"],
      broadcasts_update: [:put, "/v4/broadcasts/{id}"],
      broadcasts_delete: [:delete, "/v4/broadcasts/{id}"],
      broadcasts_stats_list: [:get, "/v4/broadcasts/stats"],
      broadcasts_stats: [:get, "/v4/broadcasts/{broadcast_id}/stats"],
      broadcasts_clicks: [:get, "/v4/broadcasts/{broadcast_id}/clicks"],

      email_templates_list: [:get, "/v4/email_templates"],
      segments_list: [:get, "/v4/segments"],

      posts_list: [:get, "/v4/posts"],
      posts_get: [:get, "/v4/posts/{id}"],

      snippets_list: [:get, "/v4/snippets"],
      snippets_get: [:get, "/v4/snippets/{id}"],
      snippets_create: [:post, "/v4/snippets"],
      snippets_update: [:put, "/v4/snippets/{id}"],

      purchases_list: [:get, "/v4/purchases"],
      purchases_get: [:get, "/v4/purchases/{id}"],
      purchases_create: [:post, "/v4/purchases"],

      webhooks_list: [:get, "/v4/webhooks"],
      webhooks_create: [:post, "/v4/webhooks"],
      webhooks_delete: [:delete, "/v4/webhooks/{id}"],

      webhook_endpoints_list: [:get, "/v4/webhook_endpoints"],
      webhook_endpoints_get: [:get, "/v4/webhook_endpoints/{id}"],
      webhook_endpoints_create: [:post, "/v4/webhook_endpoints"],
      webhook_endpoints_update: [:patch, "/v4/webhook_endpoints/{id}"],
      webhook_endpoints_delete: [:delete, "/v4/webhook_endpoints/{id}"],
      webhook_endpoints_rotate_secret: [:post, "/v4/webhook_endpoints/{id}/rotate_secret"],
      webhook_endpoints_revoke_previous_secret: [:post, "/v4/webhook_endpoints/{id}/revoke_previous_secret"],

      bulk_create_subscribers: [:post, "/v4/bulk/subscribers"],
      bulk_create_custom_fields: [:post, "/v4/bulk/custom_fields"],
      bulk_update_custom_field_values: [:post, "/v4/bulk/custom_fields/subscribers"],
      bulk_add_subscribers_to_forms: [:post, "/v4/bulk/forms/subscribers"],
      bulk_create_tags: [:post, "/v4/bulk/tags"],
      bulk_delete_tags: [:delete, "/v4/bulk/tags"],
      bulk_tag_subscribers: [:post, "/v4/bulk/tags/subscribers"],
      bulk_remove_tag_subscribers: [:delete, "/v4/bulk/tags/subscribers"]
    }.each_value(&:freeze).freeze

    # The logical response type an operation's envelope holds — the same
    # grouping as the Kit::Objects class the resource builds — for the
    # operations whose envelope key alone does not say: "stats" is three
    # different objects, "broadcast"/"broadcasts" hold BroadcastStats on the
    # stats endpoints, "email(s)" are sequence emails. Every other operation's
    # type is its envelope key singularised (subscribers => subscriber).
    TYPES = {
      account_email_stats: "email_stats",
      account_growth_stats: "growth_stats",
      subscribers_stats: "subscriber_stats",
      broadcasts_stats: "broadcast_stats",
      broadcasts_stats_list: "broadcast_stats",
      sequences_emails: "sequence_email",
      sequences_create_email: "sequence_email",
      sequences_email: "sequence_email",
      sequences_update_email: "sequence_email",
      account_creator_profile: "creator_profile"
    }.freeze
  end
end
