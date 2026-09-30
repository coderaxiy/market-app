import 'package:flutter/material.dart';

class MarketApp extends StatelessWidget {
  const MarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'emarket',
      home: Scaffold(body: Center(child: Text('emarket'))),
    );
  }
}
