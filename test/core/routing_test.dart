import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/app.dart';
import 'package:market_app/core/api/providers.dart';
import 'package:market_app/core/i18n/i18n.dart';
import 'package:market_app/core/routing/paths.dart';
import 'package:market_app/core/routing/router.dart';
import 'package:market_app/core/settings/settings.dart';
import 'package:market_app/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  var loggedIn = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    final (int, Object?) result = switch (key) {
      'GET /auth/me' =>
        loggedIn
            ? (200, {'id': 4, 'email': 'a@b.uz', 'is_active': true})
            : (401, {}),
      'POST /auth/login' => () {
        loggedIn = true;
        return (200, {'message': 'ok'});
      }(),
      'GET /cart' => (
        200,
        {
          'id': 1,
          'status': 'active',
          'items': <Object>[],
          'item_count': 3,
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

Future<(ProviderContainer, _Adapter)> _pumpApp(WidgetTester tester) async {
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
  return (c, adapter);
}

String _location(ProviderContainer c) =>
    c.read(routerProvider).routeInformationProvider.value.uri.toString();

void main() {
  group('paths', () {
    test('protected paths are prefix matches', () {
      expect(isProtectedPath('/orders'), isTrue);
      expect(isProtectedPath('/orders/5'), isTrue);
      expect(isProtectedPath('/checkout'), isTrue);
      expect(isProtectedPath('/account'), isTrue);
      expect(isProtectedPath('/ordersx'), isFalse);
      expect(isProtectedPath('/cart'), isFalse);
      expect(isProtectedPath('/'), isFalse);
    });

    test('safeNextPath refuses open redirects', () {
      expect(safeNextPath('/orders/5'), '/orders/5');
      expect(safeNextPath(null), '/');
      expect(safeNextPath('https://evil.com'), '/');
      expect(safeNextPath('//evil.com'), '/');
      expect(safeNextPath(r'/\evil.com'), '/');
      expect(safeNextPath('orders'), '/');
      expect(safeNextPath('//x', fallback: '/account'), '/account');
    });

    test('loginLocation round-trips the target', () {
      final uri = Uri.parse(loginLocation('/orders/5?tab=a&b=c'));
      expect(uri.path, '/login');
      expect(uri.queryParameters['next'], '/orders/5?tab=a&b=c');
    });

    test('slugs in paths are encoded', () {
      expect(Paths.product('my shop', 'a/b'), '/shops/my%20shop/a%2Fb');
    });
  });

  group('authRedirect', () {
    const loading = AsyncLoading<Object?>();
    const out = AsyncData<Object?>(null);
    const signedIn = AsyncData<Object?>('user');

    test('undecided while the first session check runs', () {
      expect(authRedirect(loading, Uri.parse('/orders')), isNull);
    });

    test('logged out: protected goes to login with next, public stays', () {
      expect(
        authRedirect(out, Uri.parse('/orders/5')),
        loginLocation('/orders/5'),
      );
      expect(authRedirect(out, Uri.parse('/cart')), isNull);
      expect(authRedirect(out, Uri.parse('/login')), isNull);
    });

    test('logged in: auth pages leave, safely', () {
      expect(
        authRedirect(signedIn, Uri.parse('/login?next=%2Forders')),
        '/orders',
      );
      expect(authRedirect(signedIn, Uri.parse('/register')), '/');
      expect(
        authRedirect(signedIn, Uri.parse('/login?next=https%3A%2F%2Fevil.com')),
        '/',
      );
      expect(authRedirect(signedIn, Uri.parse('/orders')), isNull);
    });

    test('a failed session check counts as logged out', () {
      final failed = AsyncError<Object?>(StateError('x'), StackTrace.empty);
      expect(
        authRedirect(failed, Uri.parse('/account')),
        loginLocation('/account'),
      );
    });
  });

  testWidgets('five tabs with labels, cart badge, and tab switching', (
    tester,
  ) async {
    await _pumpApp(tester);
    for (final key in [
      'nav.home',
      'nav.catalog',
      'nav.search',
      'nav.cart',
      'nav.profile',
    ]) {
      expect(
        find.text(translate(AppLocale.en, key)),
        findsWidgets,
        reason: key,
      );
    }
    expect(find.text('3'), findsOneWidget); // cart badge
    await tester.tap(find.text('Catalog').last);
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Catalog')),
      findsOneWidget,
    );
  });

  testWidgets(
    'logged out: /orders goes to login; signing in returns to /orders',
    (tester) async {
      final (c, adapter) = await _pumpApp(tester);
      c.read(routerProvider).go('/orders/5');
      await tester.pumpAndSettle();
      expect(_location(c), loginLocation('/orders/5'));
      expect(
        find.text(translate(AppLocale.en, 'auth.loginTitle')),
        findsOneWidget,
      );

      adapter.loggedIn = false;
      await tester.runAsync(
        () => c
            .read(sessionProvider.notifier)
            .login(email: 'a@b.uz', password: 'pw'),
      );
      await tester.pumpAndSettle();
      expect(_location(c), '/orders/5');
    },
  );

  testWidgets('session expiry on a protected screen sends the user to login', (
    tester,
  ) async {
    final (c, adapter) = await _pumpApp(tester);
    await tester.runAsync(
      () => c
          .read(sessionProvider.notifier)
          .login(email: 'a@b.uz', password: 'pw'),
    );
    c.read(routerProvider).go('/account');
    await tester.pumpAndSettle();
    expect(_location(c), '/account');

    adapter.loggedIn = false;
    c.read(sessionProvider.notifier).expire();
    await tester.pumpAndSettle();
    expect(_location(c), loginLocation('/account'));
  });

  testWidgets('unknown route shows not found with a way home', (tester) async {
    final (c, _) = await _pumpApp(tester);
    c.read(routerProvider).go('/nope/at/all');
    await tester.pumpAndSettle();
    expect(
      find.text(translate(AppLocale.en, 'notFound.title')),
      findsOneWidget,
    );
    await tester.tap(find.text(translate(AppLocale.en, 'common.retry')));
    await tester.pumpAndSettle();
    expect(_location(c), '/');
  });

  testWidgets('changing the language relabels the tabs', (tester) async {
    final (c, _) = await _pumpApp(tester);
    expect(find.text(translate(AppLocale.en, 'nav.cart')), findsWidgets);
    await tester.runAsync(
      () => c.read(settingsProvider.notifier).setLocale(AppLocale.ru),
    );
    await tester.pumpAndSettle();
    expect(find.text(translate(AppLocale.ru, 'nav.cart')), findsWidgets);
    expect(find.text(translate(AppLocale.en, 'nav.cart')), findsNothing);
  });
}
