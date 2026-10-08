import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:veriadd/veriadd.dart';

http.Response json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'Content-Type': 'application/json'},
    );

const okVerify = {
  'audit_id': 'audit-1',
  'status': 'verified',
  'confidence': 92,
  'reasons': ['postcode valid in NIPOST registry (+40)'],
  'postcode_canonical': 'LA-11-W06-TC-10',
  'nipost': {'postcode': 'LA-11-W06-TC-10', 'valid': true},
  'identity': {'provider': 'dojah', 'bvn_valid': true},
  'billed_kobo': 5000,
  'billed_ngn': 50,
};

void main() {
  group('VeriaddClient', () {
    test('requires a non-empty apiKey', () {
      expect(() => VeriaddClient(apiKey: ''), throwsArgumentError);
    });

    test('posts verify payload with auth headers', () async {
      Uri? seenUri;
      Map<String, String>? seenHeaders;
      Object? seenBody;
      final client = VeriaddClient(
        apiKey: 'vr_live_test',
        httpClient: MockClient((request) async {
          seenUri = request.url;
          seenHeaders = request.headers;
          seenBody = request.body;
          return json(200, {'data': okVerify});
        }),
      );
      addTearDown(client.close);

      final res = await client.verifyAddress(
        const VeriaddVerifyInput(postcode: 'LA-11-W06-TC-10', level: 3),
      );
      expect(res.status, 'verified');
      expect(res.confidence, 92);
      expect(seenUri.toString(),
          'https://api.veriadd.tech/api/v1/verify/address');
      expect(seenHeaders!['X-API-Key'], 'vr_live_test');
      expect(seenHeaders!['X-Request-ID'], isNotEmpty);
      expect(jsonDecode(seenBody as String),
          {'postcode': 'LA-11-W06-TC-10', 'level': 3});
    });

    test('honours baseUrl overrides and trims slashes', () async {
      Uri? seenUri;
      final client = VeriaddClient(
        apiKey: 'k',
        baseUrl: 'http://localhost:8080/',
        httpClient: MockClient((request) async {
          seenUri = request.url;
          return json(200, {
            'data': {'postcode': 'LA-11-W06-TC-10', 'valid': true}
          });
        }),
      );
      addTearDown(client.close);

      final lookup = await client.lookup('LA-11-W06-TC-10', 1);
      expect(lookup.valid, isTrue);
      expect(seenUri.toString(),
          'http://localhost:8080/api/v1/lookup?code=LA-11-W06-TC-10&level=1');
    });

    test('maps the error envelope to VeriaddError', () async {
      final client = VeriaddClient(
        apiKey: 'k',
        httpClient: MockClient((_) async => json(402, {
              'error': {
                'code': 'insufficient_credits',
                'message': 'top up',
                'request_id': 'req-1'
              }
            })),
      );
      addTearDown(client.close);

      try {
        await client.wallet();
        fail('expected VeriaddError');
      } on VeriaddError catch (e) {
        expect(e.code, 'insufficient_credits');
        expect(e.status, 402);
        expect(e.requestId, 'req-1');
      }
    });

    test('handles non-JSON error bodies', () async {
      final client = VeriaddClient(
        apiKey: 'k',
        httpClient: MockClient(
            (_) async => http.Response('gateway exploded', 502)),
      );
      addTearDown(client.close);

      try {
        await client.wallet();
        fail('expected VeriaddError');
      } on VeriaddError catch (e) {
        expect(e.status, 502);
      }
    });

    test('maps timeouts to timeout errors', () async {
      final client = VeriaddClient(
        apiKey: 'k',
        timeout: const Duration(milliseconds: 20),
        httpClient: MockClient((_) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return json(200, {'data': <String, dynamic>{}});
        }),
      );
      addTearDown(client.close);

      try {
        await client.wallet();
        fail('expected VeriaddError');
      } on VeriaddError catch (e) {
        expect(e.code, 'timeout');
      }
    });

    test('posts key creation with env', () async {
      Object? seenBody;
      final client = VeriaddClient(
        apiKey: 'k',
        httpClient: MockClient((request) async {
          seenBody = request.body;
          return json(201, {
            'data': {
              'api_key': 'vr_live_x',
              'key_prefix': 'vr_live_x',
              'warning': 'once'
            }
          });
        }),
      );
      addTearDown(client.close);

      final key = await client.createKey('test');
      expect(key.apiKey, 'vr_live_x');
      expect(jsonDecode(seenBody as String), {'env': 'test'});
    });
  });

  group('withVeriaddRetry', () {
    test('retries retryable codes then succeeds', () async {
      var n = 0;
      final out = await withVeriaddRetry(() async {
        n++;
        if (n < 3) {
          throw const VeriaddError(
              code: 'rate_limited', status: 429, message: 'slow down');
        }
        return 'ok';
      }, baseDelay: const Duration(milliseconds: 1));
      expect(out, 'ok');
      expect(n, 3);
    });

    test('bubbles non-retryable errors immediately', () async {
      var n = 0;
      await expectLater(
        withVeriaddRetry(() async {
          n++;
          throw const VeriaddError(
              code: 'invalid_api_key', status: 401, message: 'bad key');
        }, baseDelay: const Duration(milliseconds: 1)),
        throwsA(isA<VeriaddError>().having(
            (e) => e.code, 'code', 'invalid_api_key')),
      );
      expect(n, 1);
    });

    test('gives up after maxRetries', () async {
      var n = 0;
      await expectLater(
        withVeriaddRetry(() async {
          n++;
          throw const VeriaddError(
              code: 'nipost_rate_limited', status: 429, message: 'slow');
        },
            maxRetries: 2,
            baseDelay: const Duration(milliseconds: 1)),
        throwsA(isA<VeriaddError>()),
      );
      expect(n, 3);
      expect(veriaddRetryableCodes, contains('rate_limited'));
    });
  });
}
