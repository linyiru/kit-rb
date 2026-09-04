# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
