# Veriadd Dart SDK — `veriadd`

Official Dart client for the Veriadd address KYC API. works in Flutter apps, Dart servers, CLI tools and scripts.

## Install

```yaml
dependencies:
  veriadd: ^0.1.0
```

```bash
dart pub add veriadd
```

## Quickstart

```dart
import 'package:veriadd/veriadd.dart';

Future<void> main() async {
  final veriadd = VeriaddClient(
    apiKey: const String.fromEnvironment('VERIADD_KEY'),
  );

  // Primary KYC endpoint: postcode + identity cross-check
  final result = await veriadd.verifyAddress(
    const VeriaddVerifyInput(
      postcode: 'LA-11-W06-TC-10',
      state: 'LAGOS',
      bvn: '22233344455',
      phone: '08031234567',
      level: 3, // L1 free, L2 ₦30, L3 ₦50
    ),
  );

  if (result.status == 'verified' && result.confidence >= 80) {
    // proceed to onboarding — result.auditId is your CBN trail
  }
  veriadd.close();
}
```

> **Secret keys stay server-side.** A `vr_live_…` key inside a shipped app
> can be extracted. Mobile apps should call your backend, which holds the
> key; use the SDK there, or the upcoming Flutter picker widget for
> keyless postcode capture.

## Error handling

Every failure throws `VeriaddError` with `code`, `status` and `requestId`:

```dart
try {
  await veriadd.verifyAddress(VeriaddVerifyInput(postcode: code, level: 3));
} on VeriaddError catch (e) {
  if (e.code == 'insufficient_credits') {
    // pause onboarding, trigger a wallet top-up
  }
}

// Retry transient states with backoff
final result = await withVeriaddRetry(
  () => veriadd.verifyAddress(VeriaddVerifyInput(postcode: 'LA-11-W06-TC-10', level: 3)),
);
```

## Methods

| Method                                              | Endpoint                      |
| --------------------------------------------------- | ----------------------------- |
| `verifyAddress(input)`                              | `POST /v1/verify/address`     |
| `lookup(code, [level])`                             | `GET /v1/lookup`              |
| `autocomplete(q)`                                   | `GET /v1/search/autocomplete` |
| `nearby({lat, lng, radius?})`                       | `GET /v1/search/nearby`       |
| `reverse({lat, lng, maxDistanceM?})`                | `GET /v1/search/reverse`      |
| `disassemble(code)` / `assemble(input)`             | assembly endpoints            |
| `wallet()` / `usage([limit])`                       | wallet + history              |
| `topupInit(...)` / `topupVerify(ref)`               | Bachs top-ups                 |
| `kybGet()` / `kybSubmit(input)`                     | business verification         |
| `listKeys()` / `createKey([env])` / `revokeKey(id)` | API keys                      |
| `status()`                                          | live dependency status        |

Full endpoint semantics: https://veriadd.tech/docs/api
