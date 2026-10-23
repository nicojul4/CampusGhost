class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class JsonParsingException implements Exception {
  final String message;
  final Object? cause;

  JsonParsingException(this.message, [this.cause]);

  @override
  String toString() => 'JsonParsingException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

class ValidationException extends FormatException {
  const ValidationException(super.message);

  @override
  String toString() => 'ValidationException: $message';
}
