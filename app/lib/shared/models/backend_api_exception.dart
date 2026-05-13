class BackendApiException implements Exception {
  const BackendApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    return 'BackendApiException(code: $code, statusCode: $statusCode, message: $message)';
  }
}
