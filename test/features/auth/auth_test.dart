import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/core/api/api_client.dart';
import 'package:market_app/core/api/api_error.dart';
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

  test('password reset: request then confirm, bodies as documented', () async {
    final adapter = _Adapter({
      'POST /auth/password-reset/request': (202, {'message': 'ok'}),
      'POST /auth/password-reset/confirm': (200, {'message': 'ok'}),
    });
    final repo = _container(adapter).read(authRepositoryProvider);
    await repo.requestPasswordReset('a@b.uz');
    await repo.confirmPasswordReset(
      email: 'a@b.uz',
      code: '123456',
      newPassword: 'longenough',
    );
    expect(adapter.bodies['POST /auth/password-reset/request'], {
      'email': 'a@b.uz',
    });
    expect(adapter.bodies['POST /auth/password-reset/confirm'], {
      'email': 'a@b.uz',
      'code': '123456',
      'new_password': 'longenough',
    });
  });

  test(
    'a wrong reset code is a 400 DioException with the backend text',
    () async {
      final adapter = _Adapter({
        'POST /auth/password-reset/confirm': (
          400,
          {'detail': 'Invalid or expired code'},
        ),
      });
      final repo = _container(adapter).read(authRepositoryProvider);
      await expectLater(
        repo.confirmPasswordReset(
          email: 'a@b.uz',
          code: '000000',
          newPassword: 'longenough',
        ),
        throwsA(
          isA<DioException>().having(
            (e) => apiErrorMessage(e, 'fb'),
            'message',
            'Invalid or expired code',
          ),
        ),
      );
    },
  );

  test(
    'updateProfile sends only given fields and updates the session',
    () async {
      final adapter = _Adapter({
        'GET /auth/me': (200, {..._user, 'phone': null}),
        'PATCH /auth/me': (
          200,
          {..._user, 'full_name': 'Ali', 'phone': '+998901234567'},
        ),
      });
      final c = _container(adapter);
      await c.read(sessionProvider.future);
      await c
          .read(sessionProvider.notifier)
          .updateProfile(fullName: ' Ali ', phone: '+998901234567');
      expect(adapter.bodies['PATCH /auth/me'], {
        'full_name': 'Ali',
        'phone': '+998901234567',
      });
      expect(c.read(sessionProvider).value!.phone, '+998901234567');

      await c.read(sessionProvider.notifier).updateProfile(clearPhone: true);
      expect(adapter.bodies['PATCH /auth/me'], {'phone': null});
    },
  );

  test('changePassword posts both passwords; the session stays', () async {
    final adapter = _Adapter({
      'GET /auth/me': (200, _user),
      'POST /auth/me/password': (200, {'message': 'ok'}),
    });
    final c = _container(adapter);
    await c.read(sessionProvider.future);
    await c
        .read(sessionProvider.notifier)
        .changePassword(currentPassword: 'old', newPassword: 'longenough');
    expect(adapter.bodies['POST /auth/me/password'], {
      'current_password': 'old',
      'new_password': 'longenough',
    });
    expect(c.read(sessionProvider).value, isNotNull);
  });

  test('new password rule: 8 to 72 bytes', () {
    expect(isValidNewPassword('1234567'), isFalse);
    expect(isValidNewPassword('12345678'), isTrue);
    expect(isValidNewPassword('a' * 72), isTrue);
    expect(isValidNewPassword('a' * 73), isFalse);
    expect(isValidNewPassword('я' * 36), isTrue); // 72 bytes
    expect(isValidNewPassword('я' * 37), isFalse); // 74 bytes
  });

  group('401 means the session ended', () {
    Future<int> run(
      Map<String, (int, Object?)> routes,
      String method,
      String path,
    ) async {
      var expired = 0;
      final dio = createApiClient(
        cookieDir: Directory.systemTemp.createTempSync(),
        host: 'http://x',
        onUnauthorized: () => expired++,
      )..httpClientAdapter = _Adapter(routes);
      try {
        await dio.request<Object?>(path, options: Options(method: method));
      } on DioException catch (_) {}
      return expired;
    }

    test('on an ordinary call', () async {
      final n = await run({'GET /cart': (401, {})}, 'GET', '/cart');
      expect(n, 1);
    });

    test('not on login, me or password-reset', () async {
      expect(
        await run({'POST /auth/login': (401, {})}, 'POST', '/auth/login'),
        0,
      );
      expect(await run({'GET /auth/me': (401, {})}, 'GET', '/auth/me'), 0);
    });
  });
}
