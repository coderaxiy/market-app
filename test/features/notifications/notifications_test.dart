import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/core/api/providers.dart';
import 'package:market_app/core/i18n/i18n.dart';
import 'package:market_app/core/settings/settings.dart';
import 'package:market_app/features/auth/data/auth_repository.dart';
import 'package:market_app/features/notifications/application/device_service.dart';
import 'package:market_app/features/notifications/application/device_sync.dart';
import 'package:market_app/features/notifications/data/device_repository.dart';
import 'package:market_app/features/notifications/data/push_payload.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _token = 'fcm-token-0123456789';

class _Source implements PushTokenSource {
  final refresh = StreamController<String>.broadcast();

  @override
  DevicePlatform get platform => DevicePlatform.ios;

  @override
  Future<String?> currentToken() async => _token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
}

class _Adapter implements HttpClientAdapter {
  var loggedIn = false;
  var failDevices = false;
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
    bodies[key] = options.method == 'DELETE'
        ? options.queryParameters
        : options.data;
    final (int, Object?) result = switch (key) {
      'GET /auth/me' =>
        loggedIn
            ? (
                200,
                {
                  'id': 4,
                  'email': 'a@b.uz',
                  'full_name': null,
                  'is_active': true,
                },
              )
            : (401, {}),
      'POST /auth/login' => () {
        loggedIn = true;
        return (200, {'message': 'ok'});
      }(),
      'POST /auth/logout' => (200, {}),
      _ when key.endsWith('/devices') && failDevices => (500, {}),
      'PUT /devices' => (
        200,
        {
          'id': 1,
          'platform': 'ios',
          'locale': 'uz',
          'created_at': '2026-10-01T10:00:00Z',
          'updated_at': '2026-10-01T10:00:00Z',
        },
      ),
      'DELETE /devices' => (204, null),
      _ => (404, {}),
    };
    return ResponseBody.fromString(
      result.$2 == null ? '' : jsonEncode(result.$2),
      result.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ProviderContainer, _Adapter, _Source)> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final adapter = _Adapter();
  final source = _Source();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      dioProvider.overrideWithValue(
        Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
          ..httpClientAdapter = adapter,
      ),
      pushTokenSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(c.dispose);
  c.listen(deviceSyncProvider, (_, _) {});
  await c.read(sessionProvider.future);
  return (c, adapter, source);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('no registration while logged out', () async {
    final (_, adapter, _) = await _setup();
    await _settle();
    expect(adapter.calls.where((k) => k.contains('devices')), isEmpty);
  });

  test('login registers the device with the app locale', () async {
    final (c, adapter, _) = await _setup();
    await c
        .read(sessionProvider.notifier)
        .login(email: 'a@b.uz', password: 'pw');
    await _settle();
    expect(adapter.bodies['PUT /devices'], {
      'token': _token,
      'platform': 'ios',
      'locale': 'uz',
    });
  });

  test(
    'a language change re-registers; a token refresh registers the new one',
    () async {
      final (c, adapter, source) = await _setup();
      await c
          .read(sessionProvider.notifier)
          .login(email: 'a@b.uz', password: 'pw');
      await _settle();
      await c.read(settingsProvider.notifier).setLocale(AppLocale.ru);
      await _settle();
      expect((adapter.bodies['PUT /devices']! as Map)['locale'], 'ru');

      source.refresh.add('new-token-0123456789');
      await _settle();
      expect(
        (adapter.bodies['PUT /devices']! as Map)['token'],
        'new-token-0123456789',
      );
    },
  );

  test('logout unregisters first, then logs out', () async {
    final (c, adapter, _) = await _setup();
    await c
        .read(sessionProvider.notifier)
        .login(email: 'a@b.uz', password: 'pw');
    await _settle();
    await c.read(sessionProvider.notifier).logout();
    expect(adapter.bodies['DELETE /devices'], {'token': _token});
    expect(
      adapter.calls.indexOf('DELETE /devices'),
      lessThan(adapter.calls.indexOf('POST /auth/logout')),
    );
    expect(c.read(sessionProvider).value, isNull);
  });

  test('device errors never break login or logout', () async {
    final (c, adapter, _) = await _setup();
    adapter.failDevices = true;
    await c
        .read(sessionProvider.notifier)
        .login(email: 'a@b.uz', password: 'pw');
    await _settle();
    expect(c.read(sessionProvider).value, isNotNull);
    await c.read(sessionProvider.notifier).logout();
    expect(c.read(sessionProvider).value, isNull);
  });

  group('push payload', () {
    test('arrived at point: ids and UTC deadline', () {
      final p = PushPayload.fromData({
        'type': 'order_group.arrived_at_point',
        'order_id': '12',
        'group_id': '34',
        'collection_deadline': '2026-10-05T12:00:00Z',
      });
      expect(p.type, PushEventType.arrivedAtPoint);
      expect(p.orderId, 12);
      expect(p.groupId, 34);
      expect(p.collectionDeadline, DateTime.utc(2026, 10, 5, 12));
      expect(p.openOrderId, 12);
    });

    test('refund events carry the request id', () {
      final p = PushPayload.fromData({
        'type': 'refund.rejected',
        'order_id': '1',
        'group_id': '2',
        'refund_request_id': '77',
      });
      expect(p.type, PushEventType.refundRejected);
      expect(p.refundRequestId, 77);
    });

    test('unknown or malformed data does not throw', () {
      final p = PushPayload.fromData({'type': 'shipped.soon', 'order_id': 'x'});
      expect(p.type, PushEventType.unknown);
      expect(p.orderId, isNull);
      expect(p.openOrderId, isNull);
      expect(PushPayload.fromData(const {}).type, PushEventType.unknown);
    });
  });
}
