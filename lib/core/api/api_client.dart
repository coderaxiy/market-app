import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'endpoints.dart';

/// Host only, e.g. `http://10.0.2.2:8000` (Android emulator). Set with
/// `--dart-define=API_BASE_URL=...`; paths in `endpoints.dart` are relative to `/api/v1`.
const apiHost = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

const apiPrefix = '/api/v1';

/// The one API client. Auth is the httpOnly `access_token` cookie set by
/// `POST /auth/login`; the persistent jar stores it (and the guest `cart_token`) and
/// sends it back. Without a jar every call after login is 401.
///
/// Logged-out browsing is normal, so a 401 does not redirect anywhere. But the cookie
/// lasts 7 days, fixed (no refresh, docs/api-standards.md "Session lifetime"), so a 401
/// on an ordinary call means the session ended: [onUnauthorized] drops the user.
Dio createApiClient({
  required Directory cookieDir,
  String host = apiHost,
  void Function()? onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '$host$apiPrefix',
      headers: {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(
    CookieManager(PersistCookieJar(storage: FileStorage(cookieDir.path))),
  );
  if (onUnauthorized != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 401 &&
              !_unauthorizedIsExpected.contains(error.requestOptions.path)) {
            onUnauthorized();
          }
          handler.next(error);
        },
      ),
    );
  }
  return dio;
}

/// Where a 401 is an ordinary answer (no session yet, or bad credentials), not an expiry.
const _unauthorizedIsExpected = {
  AuthEndpoints.login,
  AuthEndpoints.register,
  AuthEndpoints.me,
  AuthEndpoints.passwordResetRequest,
  AuthEndpoints.passwordResetConfirm,
};
