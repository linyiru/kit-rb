# frozen_string_literal: true

module Kit
  module Webhooks
    # Event types a webhook endpoint (/v4/webhook_endpoints) can subscribe to,
    # as listed at developers.kit.com/webhooks/event-types (verified
    # 2026-09-06). Use these instead of hand-typed strings:
    #
    #   client.webhook_endpoints.create(url: url, events: [Events::SUBSCRIBER_CREATED, Events::TAG_CREATED])
    #
    # DATA_KEYS names the keys each event's `data` carries. PLANNED events are
    # documented but not yet delivered.
    module Events
      SUBSCRIBER_CREATED = "subscriber.created"
      SUBSCRIBER_ACTIVATED = "subscriber.activated"
      SUBSCRIBER_UNSUBSCRIBED = "subscriber.unsubscribed"
      SUBSCRIBER_BOUNCED = "subscriber.bounced"
      SUBSCRIBER_COMPLAINED = "subscriber.complained"
      SUBSCRIBER_SUBSCRIBED_TO_FORM = "subscriber.subscribed_to_form"
      SUBSCRIBER_ADDED_TO_SEQUENCE = "subscriber.added_to_sequence"
      SUBSCRIBER_SEQUENCE_COMPLETED = "subscriber.sequence_completed"
      SUBSCRIBER_TAG_ADDED = "subscriber.tag_added"
      SUBSCRIBER_TAG_REMOVED = "subscriber.tag_removed"
      SUBSCRIBER_CUSTOM_FIELD_VALUE_UPDATED = "subscriber.custom_field_value_updated"
      SUBSCRIBER_PRODUCT_PURCHASED = "subscriber.product_purchased" # planned
      SUBSCRIBER_LINK_CLICKED = "subscriber.link_clicked"           # planned
      SUBSCRIBER_EMAIL_OPENED = "subscriber.email_opened"           # planned
      TAG_CREATED = "tag.created"
      TAG_DELETED = "tag.deleted"
      CUSTOM_FIELD_CREATED = "custom_field.created"
      CUSTOM_FIELD_DELETED = "custom_field.deleted"
      SEQUENCE_CREATED = "sequence.created"
      SEQUENCE_DELETED = "sequence.deleted"
      SEQUENCE_PUBLISHED = "sequence.published"
      SEQUENCE_DISABLED = "sequence.disabled"
      BROADCAST_CREATED = "broadcast.created"
      BROADCAST_SENT = "broadcast.sent"
      BROADCAST_DELETED = "broadcast.deleted"
      POST_PUBLISHED = "post.published"
      LANDING_PAGE_CREATED = "landing_page.created" # planned
      LANDING_PAGE_DELETED = "landing_page.deleted" # planned

      DATA_KEYS = {
        SUBSCRIBER_CREATED => %w[subscriber], SUBSCRIBER_ACTIVATED => %w[subscriber],
        SUBSCRIBER_UNSUBSCRIBED => %w[subscriber], SUBSCRIBER_BOUNCED => %w[subscriber],
        SUBSCRIBER_COMPLAINED => %w[subscriber], SUBSCRIBER_SUBSCRIBED_TO_FORM => %w[subscriber form],
        SUBSCRIBER_ADDED_TO_SEQUENCE => %w[subscriber sequence],
        SUBSCRIBER_SEQUENCE_COMPLETED => %w[subscriber sequence],
        SUBSCRIBER_TAG_ADDED => %w[subscriber tag], SUBSCRIBER_TAG_REMOVED => %w[subscriber tag],
        SUBSCRIBER_CUSTOM_FIELD_VALUE_UPDATED => %w[subscriber custom_field],
        SUBSCRIBER_PRODUCT_PURCHASED => %w[subscriber], SUBSCRIBER_LINK_CLICKED => %w[subscriber],
        SUBSCRIBER_EMAIL_OPENED => %w[subscriber],
        TAG_CREATED => %w[tag], TAG_DELETED => %w[tag],
        CUSTOM_FIELD_CREATED => %w[custom_field], CUSTOM_FIELD_DELETED => %w[custom_field],
        SEQUENCE_CREATED => %w[sequence], SEQUENCE_DELETED => %w[sequence],
        SEQUENCE_PUBLISHED => %w[sequence], SEQUENCE_DISABLED => %w[sequence],
        BROADCAST_CREATED => %w[broadcast], BROADCAST_SENT => %w[broadcast], BROADCAST_DELETED => %w[broadcast],
        POST_PUBLISHED => %w[post],
        LANDING_PAGE_CREATED => [], LANDING_PAGE_DELETED => []
      }.freeze

      PLANNED = [
        SUBSCRIBER_PRODUCT_PURCHASED, SUBSCRIBER_LINK_CLICKED, SUBSCRIBER_EMAIL_OPENED,
        LANDING_PAGE_CREATED, LANDING_PAGE_DELETED
      ].freeze

      ALL = DATA_KEYS.keys.freeze
      AVAILABLE = (ALL - PLANNED).freeze
    end

    # Event names for the previous-generation /v4/webhooks (one event per
    # webhook, unsigned). Kept for existing integrations; new ones should use
    # webhook endpoints. REQUIRED_PARAM names the extra key the `event` hash
    # must carry for the events that are scoped to a resource:
    #
    #   client.webhooks.create(target_url: url,
    #                          event: { name: LegacyEvents::TAG_ADD, tag_id: 12 })
    module LegacyEvents
      SUBSCRIBER_ACTIVATE = "subscriber.subscriber_activate"
      SUBSCRIBER_UNSUBSCRIBE = "subscriber.subscriber_unsubscribe"
      SUBSCRIBER_BOUNCE = "subscriber.subscriber_bounce"
      SUBSCRIBER_COMPLAIN = "subscriber.subscriber_complain"
      FORM_SUBSCRIBE = "subscriber.form_subscribe"
      COURSE_SUBSCRIBE = "subscriber.course_subscribe"
      COURSE_COMPLETE = "subscriber.course_complete"
      LINK_CLICK = "subscriber.link_click"
      PRODUCT_PURCHASE = "subscriber.product_purchase"
      TAG_ADD = "subscriber.tag_add"
      TAG_REMOVE = "subscriber.tag_remove"
      PURCHASE_CREATE = "purchase.purchase_create"
      FIELD_CREATED = "custom_field.field_created"
      FIELD_DELETED = "custom_field.field_deleted"
      FIELD_VALUE_UPDATED = "custom_field.field_value_updated"

      REQUIRED_PARAM = {
        FORM_SUBSCRIBE => :form_id,
        COURSE_SUBSCRIBE => :sequence_id,
        COURSE_COMPLETE => :sequence_id,
        LINK_CLICK => :initiator_value,
        PRODUCT_PURCHASE => :product_id,
        TAG_ADD => :tag_id,
        TAG_REMOVE => :tag_id,
        FIELD_VALUE_UPDATED => :custom_field_id
      }.freeze

      ALL = [
        SUBSCRIBER_ACTIVATE, SUBSCRIBER_UNSUBSCRIBE, SUBSCRIBER_BOUNCE, SUBSCRIBER_COMPLAIN,
        FORM_SUBSCRIBE, COURSE_SUBSCRIBE, COURSE_COMPLETE, LINK_CLICK, PRODUCT_PURCHASE,
        TAG_ADD, TAG_REMOVE, PURCHASE_CREATE, FIELD_CREATED, FIELD_DELETED, FIELD_VALUE_UPDATED
      ].freeze
    end
  end
end
