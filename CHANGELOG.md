# Changelog

All notable changes to the `veriadd` Dart package are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## 0.1.0 — 2026-10-08

### Added
- `VeriaddClient` covering the full Veriadd REST surface: address verification,
  postcode lookup, autocomplete, nearby and reverse search, assembly,
  wallet and usage, Bachs top-up init/verify, KYB get/submit, API key
  management, and live service status.
- Typed models for every response, `VeriaddError{code, status, message, requestId}`
  parsed from the API error envelope.
- `withVeriaddRetry` with exponential backoff on transient codes
  (`rate_limited`, `provider_unavailable`, `nipost_rate_limited`).
- Per-request timeouts and `X-Request-ID` correlation headers.
- Mocked-transport test suite (`dart test`).
