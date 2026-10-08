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

export 'package:veriadd/src/client.dart';
export 'package:veriadd/src/errors.dart';
export 'package:veriadd/src/types.dart';
