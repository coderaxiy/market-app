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
import 'package:market_app/features/auth/presentation/auth_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

/// Answers by `METHOD path`; records request bodies.
class _Adapter implements HttpClientAdapter {
  var loggedIn = false;
  final overrides = <String, (int, Object?)>{};
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
    final (int, Object?) result =
        overrides[key] ??
        switch (key) {
          'GET /auth/me' =>
            loggedIn
                ? (200, {'id': 4, 'email': 'a@b.uz', 'is_active': true})
                : (401, {}),
          'POST /auth/login' => () {
            loggedIn = true;
            return (200, {'message': 'ok'});
          }(),
          'POST /auth/register' => (
            200,
            {'id': 4, 'email': 'a@b.uz', 'is_active': true},
          ),
          'POST /auth/password-reset/request' => (202, {'message': 'ok'}),
          'POST /auth/password-reset/confirm' => (200, {'message': 'ok'}),
          'GET /cart' => (
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
          ),
          _ => (404, {}),
        };
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

Future<(ProviderContainer, _Adapter)> _pump(
  WidgetTester tester,
  String path,
) async {
  SharedPreferences.setMockInitialValues({'locale': 'en'});
  final adapter = _Adapter();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
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
  c.read(routerProvider).go(path);
  await tester.pumpAndSettle();
  return (c, adapter);
}

String _location(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(_field(label), text);
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  test('validators return translation keys', () {
    expect(emailError(''), 'auth.emailRequired');
    expect(emailError('nope'), 'auth.emailInvalid');
    expect(emailError(' a@b.uz '), isNull);
    expect(passwordRequiredError(''), 'auth.passwordRequired');
    expect(passwordRequiredError('x'), isNull);
    expect(newPasswordError('short'), 'auth.passwordTooShort');
    expect(newPasswordError('longenough'), isNull);
    expect(resetCodeError('12345'), 'auth.codeInvalid');
    expect(resetCodeError('12a456'), 'auth.codeInvalid');
    expect(resetCodeError(' 123456 '), isNull);
  });

  testWidgets('sign in: empty form shows field errors and sends nothing', (
    tester,
  ) async {
    final (_, adapter) = await _pump(tester, '/login');
    await _tapButton(tester, t('auth.submitLogin'));
    expect(find.text(t('auth.emailRequired')), findsOneWidget);
    expect(find.text(t('auth.passwordRequired')), findsOneWidget);
    expect(adapter.calls.where((k) => k.startsWith('POST')), isEmpty);
  });

  testWidgets('sign in success follows ?next=', (tester) async {
    final (c, adapter) = await _pump(tester, '/login?next=%2Forders%2F5');
    await _type(tester, t('auth.email'), ' a@b.uz ');
    await _type(tester, t('auth.password'), 'secret');
    await _tapButton(tester, t('auth.submitLogin'));
    expect(adapter.bodies['POST /auth/login'], {
      'email': 'a@b.uz',
      'password': 'secret',
    });
    expect(_location(c), '/orders/5');
  });

  testWidgets('sign in failure shows the backend message', (tester) async {
    final (c, adapter) = await _pump(tester, '/login');
    adapter.overrides['POST /auth/login'] = (
      401,
      {'detail': 'Incorrect email or password'},
    );
    await _type(tester, t('auth.email'), 'a@b.uz');
    await _type(tester, t('auth.password'), 'bad');
    await _tapButton(tester, t('auth.submitLogin'));
    expect(find.text('Incorrect email or password'), findsOneWidget);
    expect(_location(c), '/login');
  });

  testWidgets('register: sends the name, signs in, and goes on', (
    tester,
  ) async {
    final (c, adapter) = await _pump(tester, '/register');
    await _type(tester, t('auth.fullName'), 'Ali');
    await _type(tester, t('auth.email'), 'a@b.uz');
    await _type(tester, t('auth.password'), 'secret');
    // Registration answers first; sign-in (and /auth/me) then succeed.
    adapter.loggedIn = false;
    await _tapButton(tester, t('auth.submitRegister'));
    expect(adapter.bodies['POST /auth/register'], {
      'email': 'a@b.uz',
      'password': 'secret',
      'full_name': 'Ali',
    });
    expect(
      adapter.calls,
      containsAllInOrder(['POST /auth/register', 'POST /auth/login']),
    );
    expect(_location(c), '/');
  });

  testWidgets(
    'register where the sign-in step fails explains it and opens sign in',
    (tester) async {
      final (c, adapter) = await _pump(tester, '/register?next=%2Forders');
      adapter.overrides['POST /auth/login'] = (500, {});
      await _type(tester, t('auth.email'), 'a@b.uz');
      await _type(tester, t('auth.password'), 'secret');
      await _tapButton(tester, t('auth.submitRegister'));
      expect(_location(c), '/login?next=%2Forders');
    },
  );

  testWidgets('sign in links to forgot password and register (keeping next)', (
    tester,
  ) async {
    final (c, _) = await _pump(tester, '/login?next=%2Forders');
    await _tapButton(tester, t('auth.goRegister'));
    expect(_location(c), '/register?next=%2Forders');
    c.read(routerProvider).go('/login');
    await tester.pumpAndSettle();
    await _tapButton(tester, t('auth.forgotPassword'));
    // `push` doesn't change the router's base location: check the screen instead.
    expect(find.text(t('auth.resetSubtitle')), findsOneWidget);
  });

  testWidgets(
    'forgot password: email, code and new password, then back to sign in',
    (tester) async {
      final (c, adapter) = await _pump(tester, '/forgot-password');
      await _tapButton(tester, t('auth.sendCode'));
      expect(find.text(t('auth.emailRequired')), findsOneWidget);

      await _type(tester, t('auth.email'), 'a@b.uz');
      await _tapButton(tester, t('auth.sendCode'));
      expect(adapter.bodies['POST /auth/password-reset/request'], {
        'email': 'a@b.uz',
      });
      expect(find.text(t('auth.resetCodeTitle')), findsOneWidget);
      expect(find.textContaining('a@b.uz'), findsOneWidget);

      await _tapButton(tester, t('auth.resetSubmit'));
      expect(find.text(t('auth.codeInvalid')), findsOneWidget);
      expect(find.text(t('auth.passwordTooShort')), findsOneWidget);

      adapter.overrides['POST /auth/password-reset/confirm'] = (
        400,
        {'detail': 'Invalid or expired code'},
      );
      await _type(tester, t('auth.code'), '123456');
      await _type(tester, t('auth.newPassword'), 'longenough');
      await _tapButton(tester, t('auth.resetSubmit'));
      expect(find.text('Invalid or expired code'), findsOneWidget);
      expect(_location(c), '/forgot-password');

      adapter.overrides.remove('POST /auth/password-reset/confirm');
      await _tapButton(tester, t('auth.resetSubmit'));
      expect(adapter.bodies['POST /auth/password-reset/confirm'], {
        'email': 'a@b.uz',
        'code': '123456',
        'new_password': 'longenough',
      });
      expect(_location(c), '/login');
      expect(find.text(t('auth.resetDone')), findsOneWidget);
    },
  );
}
