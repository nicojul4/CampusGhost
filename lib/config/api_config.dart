class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl = 'http://127.0.0.1:3000/api';

  // Base URL configuration (single place of truth)
  static String baseUrl = defaultBaseUrl;

  static String get reportsUrl => '$baseUrl/reports';
  static String get healthUrl => '$baseUrl/health';

  static const Duration requestTimeout = Duration(seconds: 10);
}
