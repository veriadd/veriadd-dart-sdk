/// Official Dart client for the Veriadd address KYC API.
///
/// ```dart
/// import 'package:veriadd/veriadd.dart';
///
/// final client = VeriaddClient(apiKey: const String.fromEnvironment('VERIADD_KEY'));
/// final result = await client.verifyAddress(
///   VeriaddVerifyInput(postcode: 'LA-11-W06-TC-10', state: 'LAGOS', level: 3),
/// );
/// ```
library veriadd;

export 'src/client.dart';
export 'src/errors.dart';
export 'src/types.dart';
