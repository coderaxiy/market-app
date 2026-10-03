import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../application/pickup_providers.dart';
import '../data/pickup_point.dart';

/// Opens the picker as a bottom sheet and returns the chosen point (null if dismissed).
Future<PickupPointRead?> showPickupPointPicker(
  BuildContext context, {
  int? selectedId,
}) => showModalBottomSheet<PickupPointRead>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.9,
    child: PickupPointPicker(selectedId: selectedId),
  ),
);

/// Choose the one pickup point the whole order goes to: near the buyer (when the phone can
/// say where it is) or by region. The map the storefront shows needs Yandex Maps keys; the
/// list is the fallback and works everywhere.
class PickupPointPicker extends ConsumerWidget {
  const PickupPointPicker({super.key, this.selectedId});

  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final hasLocation = ref.watch(locationSourceProvider).available;
    void pick(PickupPointRead point) => Navigator.of(context).pop(point);

    final regionTab = _RegionTab(selectedId: selectedId, onSelect: pick);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              t('checkout.choosePoint'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Expanded(
          child: hasLocation
              ? DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: t('checkout.nearMe')),
                          Tab(text: t('checkout.byRegion')),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _NearMeTab(selectedId: selectedId, onSelect: pick),
                            regionTab,
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : regionTab,
        ),
      ],
    );
  }
}

class _RegionTab extends ConsumerStatefulWidget {
  const _RegionTab({required this.selectedId, required this.onSelect});

  final int? selectedId;
  final void Function(PickupPointRead point) onSelect;

  @override
  ConsumerState<_RegionTab> createState() => _RegionTabState();
}

class _RegionTabState extends ConsumerState<_RegionTab> {
  int? _regionId;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final regions = ref.watch(regionsProvider);
    return regions.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: apiErrorMessage(error, t('state.loadFailed')),
        onRetry: () => ref.invalidate(regionsProvider),
      ),
      data: (list) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<int>(
              initialValue: _regionId,
              isExpanded: true,
              decoration: InputDecoration(labelText: t('checkout.region')),
              hint: Text(t('checkout.chooseRegion')),
              items: [
                for (final region in list)
                  DropdownMenuItem(value: region.id, child: Text(region.name)),
              ],
              onChanged: (id) => setState(() => _regionId = id),
            ),
          ),
          Expanded(
            child: _regionId == null
                ? const SizedBox.shrink()
                : _PointsForRegion(
                    regionId: _regionId!,
                    selectedId: widget.selectedId,
                    onSelect: widget.onSelect,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PointsForRegion extends ConsumerWidget {
  const _PointsForRegion({
    required this.regionId,
    required this.selectedId,
    required this.onSelect,
  });

  final int regionId;
  final int? selectedId;
  final void Function(PickupPointRead point) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final points = ref.watch(pickupPointsByRegionProvider(regionId));
    return points.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: apiErrorMessage(error, t('state.loadFailed')),
        onRetry: () => ref.invalidate(pickupPointsByRegionProvider(regionId)),
      ),
      data: (list) => PointList(
        points: list,
        selectedId: selectedId,
        onSelect: onSelect,
        emptyMessage: t('checkout.noPointsInRegion'),
      ),
    );
  }
}

class _NearMeTab extends ConsumerStatefulWidget {
  const _NearMeTab({required this.selectedId, required this.onSelect});

  final int? selectedId;
  final void Function(PickupPointRead point) onSelect;

  @override
  ConsumerState<_NearMeTab> createState() => _NearMeTabState();
}

class _NearMeTabState extends ConsumerState<_NearMeTab> {
  LatLng? _at;
  var _denied = false;
  var _locating = false;

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _denied = false;
    });
    final at = await ref.read(locationSourceProvider).current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _at = at;
      _denied = at == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final at = _at;
    if (at == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _denied
                    ? t('checkout.locationDenied')
                    : t('checkout.locationHint'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _locating ? null : _locate,
                icon: const Icon(Icons.my_location),
                label: Text(t('checkout.useMyLocation')),
              ),
            ],
          ),
        ),
      );
    }
    final points = ref.watch(nearbyPickupPointsProvider(at));
    return points.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: apiErrorMessage(error, t('state.loadFailed')),
        onRetry: () => ref.invalidate(nearbyPickupPointsProvider(at)),
      ),
      data: (list) => PointList(
        points: list,
        selectedId: widget.selectedId,
        onSelect: widget.onSelect,
        emptyMessage: t('checkout.noPointsNearby'),
      ),
    );
  }
}

/// Points as selectable tiles, with a name/street filter once there are more than five.
class PointList extends ConsumerStatefulWidget {
  const PointList({
    super.key,
    required this.points,
    required this.selectedId,
    required this.onSelect,
    required this.emptyMessage,
  });

  final List<PickupPointRead> points;
  final int? selectedId;
  final void Function(PickupPointRead point) onSelect;
  final String emptyMessage;

  @override
  ConsumerState<PointList> createState() => _PointListState();
}

class _PointListState extends ConsumerState<PointList> {
  var _needle = '';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    if (widget.points.isEmpty) return EmptyState(message: widget.emptyMessage);
    final needle = _needle.trim().toLowerCase();
    final shown = needle.isEmpty
        ? widget.points
        : [
            for (final point in widget.points)
              if ('${point.name} ${point.address.display}'
                  .toLowerCase()
                  .contains(needle))
                point,
          ];
    return Column(
      children: [
        if (widget.points.length > 5)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _needle = value),
              decoration: InputDecoration(
                hintText: t('checkout.filterPoints'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
        Expanded(
          child: shown.isEmpty
              ? EmptyState(message: t('checkout.noPointsMatch'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => PointTile(
                    point: shown[i],
                    selected: shown[i].id == widget.selectedId,
                    onTap: () => widget.onSelect(shown[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// One pickup point: name, address with landmark, today's hours, distance and phone.
class PointTile extends ConsumerWidget {
  const PointTile({
    super.key,
    required this.point,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final PickupPointRead point;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final hours = todaysHours(point.operatingHours);
    final landmark = point.address.landmark;
    final subtle = text.bodySmall?.copyWith(color: colors.mutedForeground);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? colors.accent : colors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Icon(
                  selected ? Icons.check_circle : Icons.place_outlined,
                  color: selected ? colors.accent : colors.mutedForeground,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(point.name, style: text.titleSmall),
                    if (point.address.display.isNotEmpty)
                      Text(point.address.display, style: subtle),
                    if (landmark != null) Text(landmark, style: subtle),
                    Text(
                      hours == null
                          ? t('checkout.hoursUnknown')
                          : t('checkout.todayHours', {'hours': hours}),
                      style: subtle,
                    ),
                    if (point.contactPhone.isNotEmpty)
                      Text(
                        t('checkout.pointPhone', {'phone': point.contactPhone}),
                        style: subtle,
                      ),
                  ],
                ),
              ),
              if (point.distanceKm != null)
                Text(
                  t('checkout.distanceKm', {
                    'km': point.distanceKm!.toStringAsFixed(1),
                  }),
                  style: subtle,
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
