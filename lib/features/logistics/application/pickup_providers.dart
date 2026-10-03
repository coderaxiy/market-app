import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../data/pickup_point.dart';
import '../data/pickup_repository.dart';

/// Regions with pickup points. Login required (checkout is a protected screen anyway).
final regionsProvider = FutureProvider<List<RegionRead>>(
  (ref) => ref.watch(pickupRepositoryProvider).regions(),
  retry: retryTransient,
);

/// Active pickup points of a region.
final pickupPointsByRegionProvider =
    FutureProvider.family<List<PickupPointRead>, int>(
      (ref, regionId) =>
          ref.watch(pickupRepositoryProvider).pickupPoints(regionId: regionId),
      retry: retryTransient,
    );

/// The point on the buyer's previous order, or null (a first order, or that point has
/// closed). Pre-select it at checkout so the buyer can just confirm.
final lastUsedPickupPointProvider = FutureProvider<PickupPointRead?>(
  (ref) => ref.watch(pickupRepositoryProvider).lastUsed(),
  retry: retryTransient,
);

typedef LatLng = ({double lat, double lng});

/// Radius of the "near me" search.
const nearbyRadiusKm = 25.0;

final nearbyPickupPointsProvider =
    FutureProvider.family<List<PickupPointRead>, LatLng>(
      (ref, at) => ref
          .watch(pickupRepositoryProvider)
          .nearby(lat: at.lat, lng: at.lng, radiusKm: nearbyRadiusKm),
      retry: retryTransient,
    );

/// Where the phone is. The real one wraps a location plugin (permission prompt included);
/// until it exists [NoLocationSource] is used and the "near me" tab is simply not shown.
abstract class LocationSource {
  bool get available;

  /// Null when permission is denied or location can't be read.
  Future<LatLng?> current();
}

class NoLocationSource implements LocationSource {
  const NoLocationSource();

  @override
  bool get available => false;

  @override
  Future<LatLng?> current() async => null;
}

final locationSourceProvider = Provider<LocationSource>(
  (ref) => const NoLocationSource(),
);

const _dayKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

/// Today's hours, e.g. "9–18", from `{"mon": "9-18", ...}`; null when unknown. `operating_hours`
/// is free-form JSON, so anything that isn't a non-empty string is skipped.
String? todaysHours(Map<String, dynamic> hours, [DateTime? now]) {
  final day = (now ?? DateTime.now()).weekday % 7; // DateTime: Mon=1..Sun=7
  final value = hours[_dayKeys[day]];
  return value is String && value.trim().isNotEmpty
      ? value.trim().replaceFirst('-', '–')
      : null;
}
