import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

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
/// There is no global 401 handling: logged-out browsing is normal. Actions that need a
/// session send the user to login themselves.
Dio createApiClient({required Directory cookieDir, String host = apiHost}) {
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
  return dio;
}
