# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/linyiru/kit-rb/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/linyiru/kit-rb/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/linyiru/kit-rb/compare/7ce3329...v0.1.0
[0.0.0]: https://rubygems.org/gems/kit-rb/versions/0.0.0
