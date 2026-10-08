/// Typed API error parsed from the Veriadd `{error: {code, message}}` envelope.
class VeriaddError implements Exception {
  /// Machine-readable code, e.g. `insufficient_credits`, `kyb_required`.
  final String code;

  /// HTTP status of the failed call (0 for timeouts / network failures).
  final int status;

  /// Human-readable message.
  final String message;

  /// Correlation id — quote it when contacting support, if present.
  final String? requestId;

  const VeriaddError({
    required this.code,
    required this.status,
    required this.message,
    this.requestId,
  });

  @override
  String toString() => 'VeriaddError($code, $status): $message';
}
