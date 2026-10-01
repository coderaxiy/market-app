import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_repository.dart';

/// Where the app gets its push token. The real one wraps Firebase Messaging; it needs a
/// Firebase project (`google-services.json`, `GoogleService-Info.plist`), so until that
/// exists [NoPushTokenSource] is used and the app simply doesn't register a device.
abstract class PushTokenSource {
  DevicePlatform get platform;

  /// Null when there is no token (no permission, no Firebase, simulator).
  Future<String?> currentToken();

  /// Fires when the token changes; register the new one.
  Stream<String> get onTokenRefresh;
}

class NoPushTokenSource implements PushTokenSource {
  const NoPushTokenSource();

  @override
  DevicePlatform get platform => DevicePlatform.android;

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

final pushTokenSourceProvider = Provider<PushTokenSource>(
  (ref) => const NoPushTokenSource(),
);

/// Registers this phone for the logged-in user and stops pushes before logout.
class DeviceService {
  DeviceService(this._repo, this._source);

  final DeviceRepository _repo;
  final PushTokenSource _source;
  String? _registered;

  /// Call after login and whenever the token or the app language changes. No-op without
  /// a token. Errors are swallowed: pushes are a nicety and must never break login.
  Future<void> register({required String locale}) async {
    try {
      final token = await _source.currentToken();
      if (token == null) return;
      await _registerToken(token, locale);
    } catch (_) {}
  }

  Future<void> registerToken(String token, {required String locale}) async {
    try {
      await _registerToken(token, locale);
    } catch (_) {}
  }

  Future<void> _registerToken(String token, String locale) async {
    await _repo.register(
      token: token,
      platform: _source.platform,
      locale: locale,
    );
    _registered = token;
  }

  /// Call **before** `POST /auth/logout`, which clears the cookie that authorises this.
  /// Best effort, for the same reason as [register].
  Future<void> unregister() async {
    try {
      final token = _registered ?? await _source.currentToken();
      if (token != null) await _repo.unregister(token);
    } catch (_) {}
    _registered = null;
  }
}

final deviceServiceProvider = Provider<DeviceService>(
  (ref) => DeviceService(
    ref.watch(deviceRepositoryProvider),
    ref.watch(pushTokenSourceProvider),
  ),
);
