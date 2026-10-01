import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings.dart';
import '../../auth/data/auth_repository.dart';
import 'device_service.dart';

/// Keeps this phone registered while someone is logged in: after login, when the app
/// language changes, and when the push token refreshes. Watch it once from the app root.
/// (Unregistering is done by `SessionController.logout`, before the cookie is cleared.)
final deviceSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(sessionProvider.select((s) => s.value?.id));
  final locale = ref.watch(settingsProvider.select((s) => s.locale.code));
  if (userId == null) return;

  final service = ref.read(deviceServiceProvider);
  unawaited(service.register(locale: locale));

  final refresh = ref
      .read(pushTokenSourceProvider)
      .onTokenRefresh
      .listen(
        (token) => unawaited(service.registerToken(token, locale: locale)),
      );
  ref.onDispose(refresh.cancel);
});
