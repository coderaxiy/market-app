import 'dart:convert';

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

  /// Forgotten password, step 1. Always answers 202, whether or not the account exists
  /// (no enumeration). A 6-digit code is emailed, valid 15 minutes; 3 codes per account
  /// per hour (a 429-style refusal shows as a normal `DioException`).
  Future<void> requestPasswordReset(String email) async {
    await _dio.post<void>(
      AuthEndpoints.passwordResetRequest,
      data: {'email': email},
    );
  }

  /// Step 2. `400 "Invalid or expired code"` for a wrong, expired or used code, or after
  /// 5 wrong guesses (request a new one). Success signs out every session of the user and
  /// does not log in: send them to the login screen.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      AuthEndpoints.passwordResetConfirm,
      data: {'email': email, 'code': code, 'new_password': newPassword},
    );
  }

  /// Only the fields given are sent. `phone` is 5-30 chars; [clearPhone] sends
  /// `phone: null`. Email can't be changed.
  Future<UserRead> updateProfile({
    String? fullName,
    String? phone,
    bool clearPhone = false,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      AuthEndpoints.me,
      data: {
        'full_name': ?fullName?.trim(),
        if (clearPhone) 'phone': null else 'phone': ?phone?.trim(),
      },
    );
    return UserRead.fromJson(response.data!);
  }

  /// `400` on a wrong current password. Signs out the user's other sessions; the response
  /// sets a fresh cookie (the jar stores it), so this session stays logged in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      AuthEndpoints.changePassword,
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
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

/// `new_password` rule (`POST /auth/me/password`, password reset): 8 to 72 bytes. Register
/// has no length rule, but a password shorter than 8 could never be changed back.
bool isValidNewPassword(String password) {
  final bytes = utf8.encode(password).length;
  return bytes >= 8 && bytes <= 72;
}

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

  Future<void> updateProfile({
    String? fullName,
    String? phone,
    bool clearPhone = false,
  }) async {
    final user = await _repo.updateProfile(
      fullName: fullName,
      phone: phone,
      clearPhone: clearPhone,
    );
    state = AsyncData(user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _repo.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  /// A request came back 401: the cookie expired. Drop the user, keep browsing.
  void expire() => state = const AsyncData(null);
}

final sessionProvider = AsyncNotifierProvider<SessionController, UserRead?>(
  SessionController.new,
  retry: retryTransient,
);
