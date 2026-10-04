import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/app.dart';
import 'package:market_app/core/api/providers.dart';
import 'package:market_app/core/i18n/i18n.dart';
import 'package:market_app/core/routing/router.dart';
import 'package:market_app/core/settings/settings.dart';
import 'package:market_app/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic> user = {
    'id': 4,
    'email': 'a@b.uz',
    'full_name': 'Ali Valiyev',
    'phone': null,
    'is_active': true,
  };
  var loggedIn = true;
  (int, Object?)? passwordResult;
  final calls = <String>[];
  final bodies = <String, Object?>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies[key] = options.data;
    (int, Object?) result = (404, {});
    if (key == 'GET /auth/me') {
      result = loggedIn ? (200, user) : (401, {});
    } else if (key == 'GET /cart') {
      result = (
        200,
        {
          'id': 1,
          'status': 'active',
          'items': <Object>[],
          'item_count': 0,
          'subtotal': '0.00',
          'created_at': '2026-10-01T10:00:00Z',
          'updated_at': '2026-10-01T10:00:00Z',
        },
      );
    } else if (key == 'PATCH /auth/me') {
      final body = options.data as Map<String, dynamic>;
      user = {...user, ...body};
      result = (200, user);
    } else if (key == 'POST /auth/me/password') {
      result = passwordResult ?? (200, {'message': 'ok'});
    } else if (key == 'POST /auth/logout') {
      loggedIn = false;
      result = (200, {});
    } else if (key == 'GET /orders') {
      result = (200, <Object>[]);
    }
    return ResponseBody.fromString(
      jsonEncode(result.$2),
      result.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ProviderContainer, _Adapter, SharedPreferences)> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? user,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'locale': 'en'});
  final store = await SharedPreferences.getInstance();
  final adapter = _Adapter();
  if (user != null) adapter.user = user;
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(store),
      dioProvider.overrideWithValue(
        Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
          ..httpClientAdapter = adapter,
      ),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const MarketApp()),
  );
  await tester.pumpAndSettle();
  c.read(routerProvider).go('/account');
  await tester.pumpAndSettle();
  return (c, adapter, store);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the profile; a missing phone reads "Not set"', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(find.text('a@b.uz'), findsOneWidget);
    expect(find.text(t('account.notSet')), findsOneWidget);
    expect(find.text(t('account.orders')), findsOneWidget);
  });

  testWidgets('editing sends the trimmed name and phone and shows them', (
    tester,
  ) async {
    final (_, adapter, _) = await _pump(tester);
    await _tap(tester, find.text(t('account.edit')));
    await tester.enterText(
      find.widgetWithText(TextField, t('account.fullName')),
      '  Ali V ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, t('account.phone')),
      ' +998901234567 ',
    );
    await _tap(tester, find.text(t('account.save')));
    expect(adapter.bodies['PATCH /auth/me'], {
      'full_name': 'Ali V',
      'phone': '+998901234567',
    });
    expect(find.text('+998901234567'), findsOneWidget);
    expect(find.text(t('account.saved')), findsOneWidget);
  });

  testWidgets('emptying the phone clears it; a short phone is refused', (
    tester,
  ) async {
    final (_, adapter, _) = await _pump(
      tester,
      user: {
        'id': 4,
        'email': 'a@b.uz',
        'full_name': 'Ali',
        'phone': '+998901234567',
        'is_active': true,
      },
    );
    await _tap(tester, find.text(t('account.edit')));
    await tester.enterText(
      find.widgetWithText(TextField, t('account.phone')),
      '123',
    );
    await _tap(tester, find.text(t('account.save')));
    expect(find.text(t('checkout.phoneInvalid')), findsOneWidget);
    expect(adapter.calls, isNot(contains('PATCH /auth/me')));

    await tester.enterText(
      find.widgetWithText(TextField, t('account.phone')),
      '',
    );
    await _tap(tester, find.text(t('account.save')));
    expect(adapter.bodies['PATCH /auth/me'], {
      'full_name': 'Ali',
      'phone': null,
    });
  });

  testWidgets(
    'change password: checks the form, shows a wrong-password message, then succeeds',
    (tester) async {
      final (_, adapter, _) = await _pump(tester);
      await _tap(tester, find.text(t('account.changePassword')));
      await _tap(
        tester,
        find.widgetWithText(FilledButton, t('auth.resetSubmit')),
      );
      expect(find.text(t('auth.passwordRequired')), findsOneWidget);
      expect(find.text(t('auth.passwordTooShort')), findsOneWidget);

      adapter.passwordResult = (
        400,
        {'detail': 'Current password is incorrect'},
      );
      await tester.enterText(
        find.widgetWithText(TextField, t('account.currentPassword')),
        'wrong',
      );
      await tester.enterText(
        find.widgetWithText(TextField, t('auth.newPassword')),
        'longenough',
      );
      await _tap(
        tester,
        find.widgetWithText(FilledButton, t('auth.resetSubmit')),
      );
      expect(find.text('Current password is incorrect'), findsOneWidget);

      adapter.passwordResult = null;
      await _tap(
        tester,
        find.widgetWithText(FilledButton, t('auth.resetSubmit')),
      );
      expect(adapter.bodies['POST /auth/me/password'], {
        'current_password': 'wrong',
        'new_password': 'longenough',
      });
      expect(find.text(t('account.passwordChanged')), findsOneWidget);
    },
  );

  testWidgets('language and theme change right away and are remembered', (
    tester,
  ) async {
    final (c, _, store) = await _pump(tester);
    await _tap(tester, find.text(AppLocale.ru.nativeName));
    expect(find.text(translate(AppLocale.ru, 'account.title')), findsWidgets);
    expect(store.getString('locale'), 'ru');

    await _tap(tester, find.text(translate(AppLocale.ru, 'theme.dark')));
    expect(c.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(store.getString('theme'), 'dark');
  });

  testWidgets('my orders opens the orders list', (tester) async {
    await _pump(tester);
    await _tap(tester, find.text(t('account.orders')));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(t('nav.orders')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sign out ends the session and goes home', (tester) async {
    final (c, adapter, _) = await _pump(tester);
    await _tap(tester, find.text(t('header.signOut')));
    expect(adapter.calls, contains('POST /auth/logout'));
    expect(c.read(sessionProvider).value, isNull);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(t('nav.home')),
      ),
      findsOneWidget,
    );
  });
}
