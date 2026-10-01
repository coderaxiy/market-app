import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/providers.dart';
import 'core/settings/settings.dart';
import 'features/auth/data/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  late final ProviderContainer container;
  final dio = await createDefaultApiClient(
    onUnauthorized: () => container.read(sessionProvider.notifier).expire(),
  );
  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      dioProvider.overrideWithValue(dio),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const MarketApp()),
  );
}
