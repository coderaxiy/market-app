import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../application/orders_logic.dart';
import '../application/orders_providers.dart';
import '../data/order.dart';
import 'order_widgets.dart';

/// `/orders`: the buyer's orders, newest first, filtered by tab, loading more on scroll.
class OrdersListPage extends ConsumerStatefulWidget {
  const OrdersListPage({super.key});

  @override
  ConsumerState<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends ConsumerState<OrdersListPage> {
  final _scroll = ScrollController();
  var _tab = OrderTab.all;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(ordersListProvider(_tab).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final list = ref.watch(ordersListProvider(_tab));

    return Scaffold(
      appBar: AppBar(title: Text(t('nav.orders'))),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final tab in OrderTab.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(t(orderTabLabel(tab))),
                      selected: tab == _tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const LoadingState(),
              error: (error, _) => ErrorState(
                message: apiErrorMessage(error, t('state.loadFailed')),
                onRetry: () => ref.invalidate(ordersListProvider(_tab)),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    message: _tab == OrderTab.all
                        ? '${t('orders.emptyTitle')}\n${t('orders.emptyBody')}'
                        : t('orders.tabEmpty'),
                    action: _tab == OrderTab.all
                        ? FilledButton(
                            onPressed: () => context.go(Paths.catalog),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(200, 44),
                            ),
                            child: Text(t('order.continueShopping')),
                          )
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(ordersListProvider(_tab).future),
                  child: ListView.separated(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: state.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i == state.items.length) {
                        return state.loadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: LoadingState(),
                              )
                            : state.loadMoreFailed
                            ? ErrorState(
                                onRetry: () => ref
                                    .read(ordersListProvider(_tab).notifier)
                                    .loadMore(),
                              )
                            : const SizedBox.shrink();
                      }
                      return _OrderCard(order: state.items[i]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final OrderRead order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final intl = ref.watch(settingsProvider.select((s) => s.locale.intlTag));
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final status = orderStatusInfo(order.status);
    final lines = [for (final g in order.groups) ...g.lines];
    final shown = lines.take(3).toList();
    final more = lines.length - shown.length;
    // One shipment: say where it is. Several: the order status above covers it.
    final groupLine = order.groups.length == 1
        ? t(groupStatusInfo(order.groups.first.status).label)
        : null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Paths.order(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: text.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  StatusChip(label: t(status.label), tone: status.tone),
                ],
              ),
              if (order.placedAt != null)
                Text(
                  t('order.placedAt', {'date': formatDate(order.placedAt!)}),
                  style: text.bodySmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              if (groupLine != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(groupLine),
                ),
              const SizedBox(height: 8),
              for (final line in shown)
                Text(
                  line.quantity > 1
                      ? '${line.productTitleSnapshot} × ${line.quantity}'
                      : line.productTitleSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (more > 0)
                Text(
                  t('orders.moreItems', {'count': more}),
                  style: text.bodySmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    t('cart.itemCount', {'count': orderItemCount(order)}),
                    style: text.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(order.totalAmount, intl),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
