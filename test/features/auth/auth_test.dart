import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/core/api/providers.dart';
import 'package:market_app/features/auth/data/auth_repository.dart';

const _user = {
  'id': 4,
  'email': 'a@b.uz',
  'full_name': null,
  'is_active': true,
};

/// Records `METHOD path` and bodies; answers from [routes] (`'GET /auth/me'` -> status, body).
class _Adapter implements HttpClientAdapter {
  _Adapter(this.routes);

  final Map<String, (int, Object?)> routes;
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
    final (status, body) = routes[key] ?? (200, null);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
    ..httpClientAdapter = adapter;
  return ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
}

void main() {
  test('logged out at start: /auth/me 401 means null, not an error', () async {
    final adapter = _Adapter({
      'GET /auth/me': (401, {'detail': 'Not authenticated'}),
    });
    final c = _container(adapter);
    expect(await c.read(sessionProvider.future), isNull);
    expect(c.read(sessionProvider).hasError, isFalse);
  });

  test(
    'a non-401 /auth/me failure is an error, not a logged-out state',
    () async {
      final c = _container(_Adapter({'GET /auth/me': (403, {})}));
      await expectLater(c.read(sessionProvider.future), throwsA(anything));
    },
  );

  test('login then me sets the user; logout clears it', () async {
    final adapter = _Adapter({
      'GET /auth/me': (401, {}),
      'POST /auth/login': (200, {'message': 'ok', 'token_type': 'cookie'}),
    });
    final c = _container(adapter);
    await c.read(sessionProvider.future);

    adapter.routes['GET /auth/me'] = (200, _user);
    await c
        .read(sessionProvider.notifier)
        .login(email: 'a@b.uz', password: 'pw');
    expect(c.read(sessionProvider).value!.email, 'a@b.uz');
    expect(adapter.bodies['POST /auth/login'], {
      'email': 'a@b.uz',
      'password': 'pw',
    });

    await c.read(sessionProvider.notifier).logout();
    expect(c.read(sessionProvider).value, isNull);
    expect(adapter.calls, contains('POST /auth/logout'));
  });

  test(
    'register signs in afterwards and sends null for a blank name',
    () async {
      final adapter = _Adapter({
        'GET /auth/me': (401, {}),
        'POST /auth/register': (200, _user),
      });
      final c = _container(adapter);
      await c.read(sessionProvider.future);
      adapter.routes['GET /auth/me'] = (200, _user);

      await c
          .read(sessionProvider.notifier)
          .register(email: 'a@b.uz', password: 'pw', fullName: '  ');
      expect(adapter.bodies['POST /auth/register'], {
        'email': 'a@b.uz',
        'password': 'pw',
        'full_name': null,
      });
      expect(adapter.calls.where((k) => k.startsWith('POST')).toList(), [
        'POST /auth/register',
        'POST /auth/login',
      ]);
      expect(c.read(sessionProvider).value!.id, 4);
    },
  );

  test('failed sign-in after register is reported distinctly', () async {
    final adapter = _Adapter({
      'GET /auth/me': (401, {}),
      'POST /auth/register': (200, _user),
      'POST /auth/login': (400, {'detail': 'Nope'}),
    });
    final c = _container(adapter);
    await c.read(sessionProvider.future);
    await expectLater(
      c
          .read(sessionProvider.notifier)
          .register(email: 'a@b.uz', password: 'pw'),
      throwsA(isA<SignInAfterRegisterException>()),
    );
  });

  test('expire drops the user without a request', () async {
    final adapter = _Adapter({'GET /auth/me': (200, _user)});
    final c = _container(adapter);
    expect(await c.read(sessionProvider.future), isNotNull);
    c.read(sessionProvider.notifier).expire();
    expect(c.read(sessionProvider).value, isNull);
  });
}
