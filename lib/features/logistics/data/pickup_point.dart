// Mirrors openapi/api.yaml -> PickupPointRead, NearbyPickupPointRead, RegionRead,
// PickupPointStatus, PickupPointType. Guide: sdk-contract/docs/logistics-and-pickup-points-api.md
// §2.6, §3.4, §4.

import '../../catalog/data/common.dart';

enum PickupPointStatus {
  pendingSetup,
  active,
  temporarilyClosed,
  closed;

  static PickupPointStatus parse(String value) => switch (value) {
    'pending_setup' => pendingSetup,
    'active' => active,
    'temporarily_closed' => temporarilyClosed,
    'closed' => closed,
    _ => throw FormatException('Unknown PickupPointStatus: $value'),
  };
}

enum PickupPointType {
  platformOperated,
  partnerOperated;

  static PickupPointType parse(String value) => switch (value) {
    'platform_operated' => platformOperated,
    'partner_operated' => partnerOperated,
    _ => throw FormatException('Unknown PickupPointType: $value'),
  };
}

/// `address` is free-form JSON on the backend; these keys are the documented ones.
/// Also used for `OrderPickupPointRead.address`.
class PickupPointAddress {
  const PickupPointAddress(this.raw);

  final Json raw;

  String? get region => _text('region');
  String? get district => _text('district');
  String? get street => _text('street');
  String? get landmark => _text('landmark');

  String? _text(String key) {
    final value = raw[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  /// `street, district, region`, skipping what's missing. Show [landmark] separately.
  String get display => [street, district, region].nonNulls.join(', ');
}

class RegionRead {
  const RegionRead({required this.id, required this.name, this.code});

  factory RegionRead.fromJson(Json json) => RegionRead(
    id: json['id'] as int,
    name: json['name'] as String,
    code: json['code'] as String?,
  );

  final int id;
  final String name;
  final String? code;
}

class PickupPointRead {
  const PickupPointRead({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.status,
    required this.operatingHours,
    required this.contactPhone,
    required this.regionId,
    required this.createdAt,
    required this.updatedAt,
    this.capacityUnits,
    this.distanceKm,
  });

  factory PickupPointRead.fromJson(Json json) => PickupPointRead(
    id: json['id'] as int,
    name: json['name'] as String,
    address: PickupPointAddress(json['address'] as Json),
    latitude: double.parse(json['latitude'] as String),
    longitude: double.parse(json['longitude'] as String),
    type: PickupPointType.parse(json['type'] as String),
    capacityUnits: json['capacity_units'] as int?,
    status: PickupPointStatus.parse(json['status'] as String),
    operatingHours: json['operating_hours'] as Json,
    contactPhone: json['contact_phone'] as String,
    regionId: json['region_id'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
  );

  final int id;
  final String name;
  final PickupPointAddress address;

  /// Sent as decimal strings; parsed for maps.
  final double latitude;
  final double longitude;
  final PickupPointType type;
  final int? capacityUnits;
  final PickupPointStatus status;

  /// Free-form JSON, e.g. `{"mon": "9-18"}`.
  final Json operatingHours;
  final String contactPhone;
  final int regionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Only on `GET /pickup-points/nearby` (`NearbyPickupPointRead`).
  final double? distanceKm;
}
