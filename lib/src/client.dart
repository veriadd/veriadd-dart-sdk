import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'types.dart';

/// Default production host. Override with [VeriaddClient.baseUrl] for
/// self-hosted backends or local development.
const veriaddDefaultBaseUrl = 'https://api.veriadd.tech';

/// Error codes worth retrying with backoff (transient upstream/rate states).
const veriaddRetryableCodes = <String>{
  'rate_limited',
  'provider_unavailable',
  'nipost_rate_limited',
};

int _requestSeq = 0;

String _requestId() =>
    'dart-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_requestSeq++).toRadixString(36)}';

/// Official client for the Veriadd address KYC API.
///
/// ```dart
/// import 'package:veriadd/veriadd.dart';
///
/// final client = VeriaddClient(apiKey: const String.fromEnvironment('VERIADD_KEY'));
/// final result = await client.verifyAddress(
///   VeriaddVerifyInput(postcode: 'LA-11-W06-TC-10', state: 'LAGOS', level: 3),
/// );
/// if (result.status == 'verified' && result.confidence >= 80) {
///   // proceed to onboarding — result.auditId is your CBN trail
/// }
/// ```
///
/// Pass an `http.Client` of your own (e.g. a `MockClient` in tests) via
/// [VeriaddClient.httpClient]. Call [VeriaddClient.close] when done if you did
/// not supply one.
class VeriaddClient {
  /// Secret key (`vr_live_…` / `vr_test_…`). Never ship in client-side code —
  /// mobile apps must call your backend, which holds the key.
  final String apiKey;

  final String baseUrl;
  final Duration timeout;
  final http.Client _http;
  final bool _ownsHttp;

  VeriaddClient({
    required this.apiKey,
    String? baseUrl,
    Duration? timeout,
    http.Client? httpClient,
  })  : baseUrl = _trimBase(baseUrl ?? veriaddDefaultBaseUrl),
        timeout = timeout ?? const Duration(seconds: 15),
        _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null {
    if (apiKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'VeriaddClient requires an apiKey');
    }
  }

  static String _trimBase(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// Release resources if this client created its own HTTP client.
  void close() {
    if (_ownsHttp) _http.close();
  }

  Future<T> _request<T>(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    required T Function(dynamic json) decode,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-API-Key': apiKey,
      'X-Request-ID': _requestId(),
    };
    Future<http.Response> call() => method == 'GET'
        ? _http.get(uri, headers: headers)
        : _http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));

    late final http.Response res;
    try {
      res = await call().timeout(timeout);
    } on TimeoutException {
      throw VeriaddError(
        code: 'timeout',
        status: 0,
        message: 'Request timed out after ${timeout.inMilliseconds}ms',
      );
    } catch (e) {
      throw VeriaddError(code: 'network_error', status: 0, message: '$e');
    }

    dynamic decoded = const <String, dynamic>{};
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      // fall through with empty body
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final rawErr =
          decoded is Map<String, dynamic> ? decoded['error'] : null;
      final err = rawErr is Map
          ? rawErr.cast<String, dynamic>()
          : const <String, dynamic>{};
      throw VeriaddError(
        code: '${err['code'] ?? 'http_${res.statusCode}'}',
        status: res.statusCode,
        message: '${err['message'] ?? 'Request failed (${res.statusCode})'}',
        requestId: err['request_id'] as String?,
      );
    }
    final payload =
        decoded is Map<String, dynamic> && decoded.containsKey('data')
            ? decoded['data']
            : decoded;
    return decode(payload);
  }

  static Map<String, dynamic> _asMap(dynamic json) {
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return json.cast<String, dynamic>();
    throw VeriaddError(
      code: 'bad_response',
      status: 0,
      message: 'Unexpected response shape from the Veriadd API',
    );
  }

  static List<T> _list<T>(
      dynamic json, T Function(Map<String, dynamic>) fromJson) {
    if (json is! List) return <T>[];
    return <T>[
      for (final e in json)
        if (e is Map<String, dynamic>) fromJson(e),
    ];
  }

  /// Verify an address + optional identity cross-checks. The money endpoint.
  Future<VeriaddVerifyResult> verifyAddress(VeriaddVerifyInput input) {
    return _request('POST', '/api/v1/verify/address',
        body: input.toJson(),
        decode: (json) => VeriaddVerifyResult.fromJson(
            _asMap(json)));
  }

  /// Direct NIPOST postcode lookup. L1 is free.
  Future<VeriaddNipostLookup> lookup(String code, [int level = 1]) {
    return _request('GET', '/api/v1/lookup',
        query: {'code': code, 'level': '$level'},
        decode: (json) =>
            VeriaddNipostLookup.fromJson(_asMap(json)));
  }

  /// Segment-aware postcode typeahead.
  Future<dynamic> autocomplete(String q) {
    return _request('GET', '/api/v1/search/autocomplete',
        query: {'q': q}, decode: (json) => json);
  }

  /// Postcodes within a radius (metres, default 300) of a coordinate.
  Future<dynamic> nearby({
    required double lat,
    required double lng,
    double? radius,
  }) {
    return _request('GET', '/api/v1/search/nearby',
        query: {
          'lat': '$lat',
          'lng': '$lng',
          if (radius != null) 'radius': '$radius',
        },
        decode: (json) => json);
  }

  /// Resolve a coordinate to the nearest postcode.
  Future<dynamic> reverse({
    required double lat,
    required double lng,
    double? maxDistanceM,
  }) {
    return _request('GET', '/api/v1/search/reverse',
        query: {
          'lat': '$lat',
          'lng': '$lng',
          if (maxDistanceM != null) 'max_distance_m': '$maxDistanceM',
        },
        decode: (json) => json);
  }

  /// Parse a postcode into segments (native NIPOST shape).
  Future<dynamic> disassemble(String code) {
    return _request('GET', '/api/v1/assembly/disassemble',
        query: {'code': code}, decode: (json) => json);
  }

  /// Assemble segments into a canonical postcode.
  Future<dynamic> assemble(VeriaddAssembleInput input) {
    return _request('POST', '/api/v1/assembly/assemble',
        body: input.toJson(), decode: (json) => json);
  }

  /// Wallet balance + pricing for this key.
  Future<VeriaddWallet> wallet() {
    return _request('GET', '/api/v1/wallet',
        decode: (json) =>
            VeriaddWallet.fromJson(_asMap(json)));
  }

  /// Metered call history (1–200, default 50).
  Future<List<VeriaddUsageRow>> usage([int limit = 50]) {
    return _request('GET', '/api/v1/usage',
        query: {'limit': '$limit'},
        decode: (json) => _list(json, VeriaddUsageRow.fromJson));
  }

  /// Start a Bachs wallet top-up; redirect the user to `authorizationUrl`.
  Future<VeriaddTopupInit> topupInit({
    required int amountKobo,
    required String email,
    String? callbackUrl,
  }) {
    return _request('POST', '/api/v1/wallet/topup/initialize',
        body: {
          'amount_kobo': amountKobo,
          'email': email,
          if (callbackUrl != null) 'callback_url': callbackUrl,
        },
        decode: (json) =>
            VeriaddTopupInit.fromJson(_asMap(json)));
  }

  /// Verify a top-up reference and credit the wallet (idempotent).
  Future<VeriaddTopupVerify> topupVerify(String reference) {
    return _request('GET', '/api/v1/wallet/topup/verify',
        query: {'reference': reference},
        decode: (json) =>
            VeriaddTopupVerify.fromJson(_asMap(json)));
  }

  /// Current workspace KYB submission (null when never submitted).
  Future<VeriaddKYB?> kybGet() {
    return _request('GET', '/api/v1/kyb', decode: (json) {
      if (json == null) return null;
      return VeriaddKYB.fromJson(_asMap(json));
    });
  }

  /// Submit (or resubmit) KYB business details.
  Future<VeriaddKYB> kybSubmit(VeriaddKYBInput input) {
    return _request('POST', '/api/v1/kyb',
        body: input.toJson(),
        decode: (json) =>
            VeriaddKYB.fromJson(_asMap(json)));
  }

  /// Live dependency status (public — key is harmless if set).
  Future<VeriaddStatus> status() {
    return _request('GET', '/api/v1/status',
        decode: (json) =>
            VeriaddStatus.fromJson(_asMap(json)));
  }

  /// List key prefixes (full keys are never returned).
  Future<List<VeriaddKeyInfo>> listKeys() {
    return _request('GET', '/api/v1/keys',
        decode: (json) => _list(json, VeriaddKeyInfo.fromJson));
  }

  /// Issue a key. The full secret is shown once — store it immediately.
  Future<VeriaddCreatedKey> createKey([String env = 'live']) {
    return _request('POST', '/api/v1/keys',
        body: {'env': env},
        decode: (json) =>
            VeriaddCreatedKey.fromJson(_asMap(json)));
  }

  /// Revoke a key by id. Immediate.
  Future<Map<String, dynamic>> revokeKey(String id) {
    return _request('POST', '/api/v1/keys/$id/revoke', decode: (json) {
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return json.cast<String, dynamic>();
      return <String, dynamic>{};
    });
  }
}

/// Run [fn] with exponential backoff on retryable [VeriaddError] codes.
/// Non-retryable errors bubble immediately.
Future<T> withVeriaddRetry<T>(
  Future<T> Function() fn, {
  int maxRetries = 3,
  Set<String>? retryable,
  Duration baseDelay = const Duration(seconds: 1),
}) async {
  final codes = retryable ?? veriaddRetryableCodes;
  for (var attempt = 0;; attempt++) {
    try {
      return await fn();
    } on VeriaddError catch (e) {
      if (attempt >= maxRetries || !codes.contains(e.code)) rethrow;
      await Future.delayed(baseDelay * (1 << attempt));
    }
  }
}
