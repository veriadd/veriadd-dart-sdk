import 'package:veriadd/veriadd.dart';

/// Minimal end-to-end example. Requires a test key:
/// `dart run example/main.dart` with `--define=VERIADD_KEY=vr_test_...`
Future<void> main() async {
  const apiKey = String.fromEnvironment('VERIADD_KEY');
  if (apiKey.isEmpty) {
    print('Set --define=VERIADD_KEY=vr_test_... and retry.');
    return;
  }
  final veriadd = VeriaddClient(apiKey: apiKey);
  try {
    final lookup = await veriadd.lookup('LA-11-W06-TC-10', 1);
    print('lookup: ${lookup.postcode} valid=${lookup.valid}');

    final status = await veriadd.status();
    print('status: ${status.service} ${status.version}');
  } on VeriaddError catch (e) {
    print('failed: $e');
  } finally {
    veriadd.close();
  }
}
