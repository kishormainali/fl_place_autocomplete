/// Error codes shared by all platforms.
enum PlaceAutocompleteErrorCode {
  /// API key missing or rejected.
  invalidApiKey,

  /// Quota exceeded.
  quotaExceeded,

  /// Network failure.
  networkError,

  /// Malformed request.
  invalidRequest,

  /// Place not found.
  notFound,

  /// Session already ended.
  sessionEnded,

  /// Anything else.
  unknown,
}

/// Thrown for Places failures.
class PlaceAutocompleteException implements Exception {
  /// Creates an exception.
  const PlaceAutocompleteException({required this.code, this.message});

  /// Error code.
  final PlaceAutocompleteErrorCode code;

  /// Native message.
  final String? message;

  @override
  String toString() => 'PlaceAutocompleteException(${code.name}: $message)';
}
