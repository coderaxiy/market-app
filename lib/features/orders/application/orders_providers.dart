import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../catalog/data/catalog_repository.dart' show Page;
import '../data/order.dart';
import '../data/order_repository.dart';
import 'orders_logic.dart';

/// Orders per request. The API allows up to 100.
const ordersPageSize = 20;

class OrdersListState {
  const OrdersListState({
    required this.items,
    this.total,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<OrderRead> items;
  final int? total;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  OrdersListState copyWith({bool? loadingMore, bool? loadMoreFailed}) =>
      OrdersListState(
        items: items,
        total: total,
        hasMore: hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// The buyer's orders for one tab, newest first, a page at a time.
class OrdersListController extends AsyncNotifier<OrdersListState> {
  OrdersListController(this.tab);

  final OrderTab tab;

  bool _hasMore(Page<OrderRead> page, int loaded) => page.total != null
      ? loaded < page.total!
      : page.items.length == ordersPageSize;

  @override
  Future<OrdersListState> build() async {
    final page = await ref
        .read(orderRepositoryProvider)
        .orders(statuses: statusesForTab(tab), limit: ordersPageSize);
    return OrdersListState(
      items: page.items,
      total: page.total,
      hasMore: _hasMore(page, page.items.length),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await ref
          .read(orderRepositoryProvider)
          .orders(
            statuses: statusesForTab(tab),
            skip: current.items.length,
            limit: ordersPageSize,
          );
      final items = [...current.items, ...page.items];
      state = AsyncData(
        OrdersListState(
          items: items,
          total: page.total ?? current.total,
          hasMore: page.items.isNotEmpty && _hasMore(page, items.length),
        ),
      );
    } catch (_) {
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

final ordersListProvider =
    AsyncNotifierProvider.family<
      OrdersListController,
      OrdersListState,
      OrderTab
    >(OrdersListController.new, retry: retryTransient);

/// One order with its groups and lines. Re-fetch it after any group action: its status
/// is computed from its groups.
final orderProvider = FutureProvider.family<OrderRead, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).order(id),
  retry: retryTransient,
);

typedef GroupRef = ({int orderId, int groupId});

/// Collection deadline and per-item state for a group at the pickup point. Null until it
/// gets there (the backend answers 404: "still on the way").
final pickupStatusProvider = FutureProvider.family<PickupStatusRead?, GroupRef>(
  (ref, id) =>
      ref.watch(orderRepositoryProvider).pickupStatus(id.orderId, id.groupId),
  retry: retryTransient,
);
