import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class MarketApp extends StatelessWidget {
  const MarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'emarket',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const Scaffold(body: Center(child: Text('emarket'))),
    );
  }
}
