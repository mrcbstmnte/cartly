/// Carries the backend's own rejection message so the UI can show the reason
/// a request failed (US-2) instead of a generic error.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
