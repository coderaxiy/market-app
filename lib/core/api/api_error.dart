import 'package:dio/dio.dart';

int? _status(Object error) =>
    error is DioException ? error.response?.statusCode : null;

bool isUnauthorized(Object error) => _status(error) == 401;
bool isForbidden(Object error) => _status(error) == 403;
bool isNotFound(Object error) => _status(error) == 404;

/// 4xx never succeeds on retry; network errors and 5xx might.
bool isRetryable(Object error) {
  final code = _status(error);
  return code == null || code >= 500;
}

/// The only way to show a backend message. FastAPI sends a human-readable *string*
/// `detail` for business errors (400/401/403/404/409), safe to show as-is. A 422 sends a
/// list of objects and structured details (e.g. `price_changed`) are maps; both fall
/// back to the caller's localized message.
String apiErrorMessage(Object error, String fallback) {
  if (error is! DioException) return fallback;
  final data = error.response?.data;
  final detail = data is Map<String, dynamic> ? data['detail'] : null;
  return detail is String && detail.trim().isNotEmpty ? detail : fallback;
}
