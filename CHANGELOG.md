# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-06

The hardening pass (`docs/TASKS.md`): two real-API bugs fixed, the surface
completed to all 83 documented operations, receiver-side webhook support, and
contract tests over every envelope, request body and 204.

### Added
- The two operations 0.2.0 lacked: `subscribers.update_location` (PATCH) and
  `webhook_endpoints.update` (PATCH: rename, change URL, pause/resume with
  `status`, replace `events`). All 83 documented operations now have a method.
- Incoming webhooks: `Kit::Webhooks::Signature.verify!`/`verify?` (HMAC-SHA256
  `X-Kit-Signature`, replay window, rotation-aware, multiple secrets),
  `Kit::Webhooks::Delivery.from_request`/`parse` with typed `Event`s, and the
  event-name constants `Kit::Webhooks::Events` (28) / `LegacyEvents` (15, with
  `REQUIRED_PARAM`).
- `Kit::Objects::WebhookEndpoint#secret` — the signing secret Kit returns only on
  `create` and `rotate_secret`.
- `Pagination#total_count` / `Collection#total_count` (send
  `include_total_count: true`); `Collection#size`, `#length`, `#empty?`, `#[]`
  and a compact `#inspect`.
- Response fields the spec declares: `Account#timezone`/`#plan` (typed) and
  `#sending_addresses`; `Post#content`; `SequenceEmail#content`;
  `Subscriber#added_at`/`#tagged_at`/`#referrer`/`#referrer_utm_parameters`/
  `#attribution`/`#tags`/`#tag_names`/`#tag_ids`/`#stats`; `Tag#tagged_at`;
  `CustomField#created_at`.
- `sequences.get`/`sequences.email` accept `include: "stats"`;
  `subscribers.stats` accepts `email_sent_after`/`email_sent_before`.
- Error classes: `ConflictError` (409), `PayloadTooLargeError` (413),
  `UnexpectedResponseError` (a 2xx whose body is not the documented shape),
  `TransportError` with `TimeoutError` and `ConnectionError` (the http.rb
  exception is kept as `cause`). `APIError#method`/`#path`; messages now read
  `"GET /v4/subscribers/1 failed with status 404: ..."`.
- `Connection#request_with_status`.

### Changed
- **Breaking:** the `bulk` methods return `Kit::Objects::BulkResult`
  (`items`, typed `failures`, `async?` for a 202) instead of the raw Hash.
- **Breaking:** `broadcasts.create/update`, `sequences.create/update`,
  `sequences.create_email/update_email`, `snippets.create/update` and
  `purchases.create` take explicit keyword arguments (the fields the spec
  documents) instead of `**attributes`; an unknown field raises
  `ArgumentError`. Fields not passed are omitted; an explicit `nil` is sent,
  which Kit uses to clear `send_days`/`email_template_id`/`send_at`.
- **Breaking:** `subscribers.unsubscribe` returns `nil` (the API answers 204).
- Retries: `Retry-After` is capped at `max_backoff`; a 5xx or transport
  failure is retried only for idempotent verbs (never a POST); a 429 is still
  retried for every verb.
- Follow-up page requests drop `include_total_count` and any `before` cursor.
- `Client`, `Configuration`, `Connection`, `Auth::*` and `OAuth::Token`
  mask credentials in `#inspect`.
- Path ids are percent-encoded; a nil/blank id raises `ArgumentError`.
- One http.rb client is built per `Connection` instead of per request.

### Fixed
- `subscribers.unsubscribe` raised `NoMethodError` against the real API (204,
  no body).
- `webhook_endpoints.create`/`rotate_secret` silently discarded the one-time
  signing secret.
- A response with an unexpected shape raised `KeyError`/`NoMethodError`
  instead of a `Kit::Error`.
- The error-mapping specs really slept through retries (60 s per CI run).

## [0.2.0] - 2026-09-04

### Changed
- **Breaking:** the stats and analytics endpoints now return typed value objects
  instead of raw hashes, matching every other resource:
  `broadcasts.stats`/`stats_list` → `Objects::BroadcastStats` (the nested metrics
  flattened), `broadcasts.clicks` → `Collection[Objects::BroadcastClick]`,
  `subscribers.stats` → `Objects::SubscriberStats`, `account.email_stats` →
  `Objects::EmailStats`, and `account.growth_stats` → `Objects::GrowthStats`.

### Removed
- `Objects::Raw` (the identity used by the old raw-hash stats returns).

## [0.1.0] - 2026-09-04

First feature-complete release: the entire Kit API v4 surface — all 81 documented
operations across every resource — verified against the vendored OpenAPI document.

### Added
- Full resource coverage via `client.`: `account` (colors, creator_profile,
  email/growth stats), `subscribers` (list/get/create/update/unsubscribe, filter,
  tags, stats, location), `tags`, `custom_fields`, `forms`, `sequences` (incl.
  emails and subscribers), `broadcasts` (incl. stats and click reports),
  `email_templates`, `segments`, `posts`, `snippets`, `purchases`, `webhooks`,
  `webhook_endpoints`, and `bulk` (all eight batch operations).
- OAuth 2.0: `client_credentials` grant and RFC 7009 token `revoke`, alongside
  the existing authorization-code / refresh / PKCE flows.
- `Base#one`/`#collection` helpers centralising single-object and cursor-list
  plumbing (POST-based lists supported for the filter endpoints).
- Testing layers: WebMock unit specs, an OpenAPI list-envelope contract test,
  VCR integration cassettes (secrets scrubbed) replayed in CI, `rake smoke`
  (live read-only), and an opt-in e2e lifecycle. Full RBS + Steep.
- Trusted Publishing release workflow (GitHub Actions OIDC → RubyGems).

## [0.0.0] - 2026-09-04

Name-reservation release: the P0 foundation and a working `GET /v4/account`
vertical slice. Not yet feature-complete — resources land in 0.1.0 per docs/DESIGN.md.

### Added
- P0 foundations: gem skeleton on the clean `Kit` namespace, with rspec +
  rubocop + steep gates green on CI (Ruby 3.2–3.4).
- `Kit::Client` with API-key (`X-Kit-Api-Key`) and OAuth 2.0 bearer auth.
- `http.rb`-backed `Kit::Connection` with JSON handling and a typed error
  hierarchy (`Kit::AuthenticationError`, `NotFoundError`, `RateLimitError`, …).
- `GET /v4/account` vertical slice returning immutable `Data` value objects.
- Tags resource: list, create, update, tag/remove a subscriber, list a tag
  subscribers.
- Subscribers resource: list (auto-paginating), get, create, update, unsubscribe.
- OAuth 2.0 authorization-code flow: `Kit::OAuth::Client` (authorize URL,
  code exchange, single-use refresh), PKCE (S256) helper, and `Token` object.
- Cursor pagination engine (`Kit::Collection#auto_paging_each`) and automatic
  429/5xx retry with backoff.
- RBS signatures for the public surface.

[Unreleased]: https://github.com/linyiru/kit-rb/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/linyiru/kit-rb/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/linyiru/kit-rb/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/linyiru/kit-rb/compare/7ce3329...v0.1.0
[0.0.0]: https://rubygems.org/gems/kit-rb/versions/0.0.0
