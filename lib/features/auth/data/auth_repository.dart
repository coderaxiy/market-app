import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/providers.dart';
import 'user.dart';

/// Auth is the httpOnly `access_token` cookie set by login; the client's cookie jar
/// stores it. Login and register also merge the guest cart into the user's, so refetch
/// the cart afterwards.
class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<void> login({required String email, required String password}) async {
    await _dio.post<void>(
      AuthEndpoints.login,
      data: {'email': email, 'password': password},
    );
  }

  /// Register does not sign in; the storefront logs in right after, and so do we.
  /// If the second step fails the account exists: send the user to the login screen.
  Future<void> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final name = fullName?.trim();
    await _dio.post<void>(
      AuthEndpoints.register,
      data: {
        'email': email,
        'password': password,
        'full_name': name == null || name.isEmpty ? null : name,
      },
    );
  }

  Future<void> logout() async {
    await _dio.post<void>(AuthEndpoints.logout);
  }

  /// The signed-in user, or null when there is no valid session (401).
  Future<UserRead?> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(AuthEndpoints.me);
      return UserRead.fromJson(response.data!);
    } on DioException catch (error) {
      if (isUnauthorized(error)) return null;
      rethrow;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);

/// Register succeeded but the automatic sign-in that follows did not.
class SignInAfterRegisterException implements Exception {
  const SignInAfterRegisterException(this.cause);

  final Object cause;
}

/// The current user; null = logged out (a normal state: browsing works logged out).
class SessionController extends AsyncNotifier<UserRead?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<UserRead?> build() => _repo.me();

  Future<void> login({required String email, required String password}) async {
    await _repo.login(email: email, password: password);
    state = AsyncData(await _repo.me());
  }

  Future<void> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    await _repo.register(email: email, password: password, fullName: fullName);
    try {
      await _repo.login(email: email, password: password);
    } catch (error) {
      throw SignInAfterRegisterException(error);
    }
    state = AsyncData(await _repo.me());
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  /// A request came back 401: the cookie expired. Drop the user, keep browsing.
  void expire() => state = const AsyncData(null);
}

/// Riverpod retries failed providers by default, 4xx included. A session check only
/// retries transient failures (network, 5xx), a few times.
Duration? _retry(int count, Object error) =>
    count < 3 && error is DioException && isRetryable(error)
    ? Duration(seconds: 1 << count)
    : null;

final sessionProvider = AsyncNotifierProvider<SessionController, UserRead?>(
  SessionController.new,
  retry: _retry,
);
