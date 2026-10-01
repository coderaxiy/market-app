// Mirrors openapi/api.yaml -> DeviceRegisterRequest, DeviceRead, DevicePlatform.
// Guide: sdk-contract/docs/notifications-api.md.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/endpoints.dart';
import '../../../core/api/providers.dart';
import '../../catalog/data/common.dart';

enum DevicePlatform { android, ios }

class DeviceRead {
  const DeviceRead({
    required this.id,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
    this.locale,
  });

  factory DeviceRead.fromJson(Json json) => DeviceRead(
    id: json['id'] as int,
    platform: DevicePlatform.values.byName(json['platform'] as String),
    locale: json['locale'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  final int id;
  final DevicePlatform platform;
  final String? locale;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Both calls need login. The token is the FCM registration token (Android) or the
/// APNs-backed FCM token (iOS), 10-512 chars.
class DeviceRepository {
  const DeviceRepository(this._dio);

  final Dio _dio;

  /// Register or refresh this phone. A token already registered to another account moves
  /// to this one, so a shared phone only notifies the newest login. [locale] is `uz`,
  /// `ru` or `en`; without it the text is Uzbek.
  Future<DeviceRead> register({
    required String token,
    required DevicePlatform platform,
    String? locale,
  }) async {
    final response = await _dio.put<Json>(
      DeviceEndpoints.devices,
      data: {'token': token, 'platform': platform.name, 'locale': locale},
    );
    return DeviceRead.fromJson(response.data!);
  }

  /// `204` also for unknown tokens and other users' tokens. Call it before logout.
  Future<void> unregister(String token) async {
    await _dio.delete<void>(
      DeviceEndpoints.devices,
      queryParameters: {'token': token},
    );
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(dioProvider)),
);
