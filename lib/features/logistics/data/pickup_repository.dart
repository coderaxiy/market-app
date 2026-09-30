import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/endpoints.dart';
import '../../../core/api/providers.dart';
import '../../catalog/data/common.dart';
import 'pickup_point.dart';

/// Login required, except [nearby]. One pickup point covers a whole order.
class PickupRepository {
  const PickupRepository(this._dio);

  final Dio _dio;

  Future<List<RegionRead>> regions() async {
    final response = await _dio.get<List<dynamic>>(PickupEndpoints.regions);
    return readList(response.data, RegionRead.fromJson);
  }

  /// Active points only.
  Future<List<PickupPointRead>> pickupPoints({int? regionId}) async {
    final response = await _dio.get<List<dynamic>>(
      PickupEndpoints.pickupPoints,
      queryParameters: {'region_id': ?regionId},
    );
    return readList(response.data, PickupPointRead.fromJson);
  }

  /// The point on the buyer's previous order, or null (first order, or that point closed).
  Future<PickupPointRead?> lastUsed() async {
    final response = await _dio.get<Json?>(PickupEndpoints.lastUsed);
    final data = response.data;
    return data == null ? null : PickupPointRead.fromJson(data);
  }

  /// Public. Sorted by the server; each point carries `distanceKm`.
  Future<List<PickupPointRead>> nearby({
    required double lat,
    required double lng,
    double? radiusKm,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      PickupEndpoints.nearby,
      queryParameters: {'lat': lat, 'lng': lng, 'radius_km': ?radiusKm},
    );
    return readList(response.data, PickupPointRead.fromJson);
  }
}

final pickupRepositoryProvider = Provider<PickupRepository>(
  (ref) => PickupRepository(ref.watch(dioProvider)),
);
