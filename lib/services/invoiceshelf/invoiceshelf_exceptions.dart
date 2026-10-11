/// Thrown when the server returns 401 Unauthorized.
class InvoiceShelfAuthException implements Exception {
  final String message;
  const InvoiceShelfAuthException([this.message = 'Unauthorized']);
  @override
  String toString() => 'InvoiceShelfAuthException: $message';
}

/// Thrown when the server returns 429 Too Many Requests.
class InvoiceShelfRateLimitException implements Exception {
  final int? retryAfterSeconds;
  const InvoiceShelfRateLimitException({this.retryAfterSeconds});
  @override
  String toString() =>
      'InvoiceShelfRateLimitException: rate limit exceeded'
      '${retryAfterSeconds != null ? ", retry after ${retryAfterSeconds}s" : ""}';
}

/// Thrown for 4xx / 5xx responses other than 401 / 429.
class InvoiceShelfApiException implements Exception {
  final int statusCode;
  final String message;
  const InvoiceShelfApiException(this.statusCode, this.message);
  @override
  String toString() => 'InvoiceShelfApiException[$statusCode]: $message';
}

/// Thrown when the host is not reachable (network timeout or DNS failure).
class InvoiceShelfNetworkException implements Exception {
  final String message;
  const InvoiceShelfNetworkException([this.message = 'Network error']);
  @override
  String toString() => 'InvoiceShelfNetworkException: $message';
}
