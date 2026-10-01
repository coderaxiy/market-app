import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/i18n.dart';
import 'core/settings/settings.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/application/device_sync.dart';

class MarketApp extends ConsumerWidget {
  const MarketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final t = ref.watch(tProvider);
    ref.watch(deviceSyncProvider);
    return MaterialApp(
      title: t('common.appName'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: Locale(settings.locale.code),
      supportedLocales: [for (final l in AppLocale.values) Locale(l.code)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Center(child: Text(t('common.tagline')))),
    );
  }
}
