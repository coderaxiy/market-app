import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../catalog/presentation/product_card.dart';
import '../../checkout/data/checkout.dart';
import '../../logistics/application/pickup_providers.dart' show todaysHours;
import '../application/orders_logic.dart';
import '../application/orders_providers.dart';
import '../data/order.dart';
import '../data/order_repository.dart';
import '../data/refund.dart';
import 'return_sheet.dart';
import 'order_widgets.dart';

/// `/orders/:id`. With `placed` (right after checkout) it opens with a thank-you banner.
/// Fulfillment and refunds are per shop, so each shop's shipment is its own section.
class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.placed = false,
  });

  final int orderId;
  final bool placed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final order = ref.watch(orderProvider(orderId));
    return order.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: isNotFound(error)
            ? ErrorState(
                message: t('notFound.body'),
                onRetry: () => context.go(Paths.orders),
              )
            : ErrorState(
                message: apiErrorMessage(error, t('state.loadFailed')),
                onRetry: () => ref.invalidate(orderProvider(orderId)),
              ),
      ),
      data: (data) => _OrderView(order: data, placed: placed),
    );
  }
}

class _OrderView extends ConsumerWidget {
  const _OrderView({required this.order, required this.placed});

  final OrderRead order;
  final bool placed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final intl = ref.watch(settingsProvider.select((s) => s.locale.intlTag));
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final status = orderStatusInfo(order.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('order.title', {'number': order.orderNumber})),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(orderProvider(order.id).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (placed)
              Card(
                color: colors.success.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('order.placedTitle'), style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text(t('order.placedBody')),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => context.go(Paths.catalog),
                        child: Text(t('order.continueShopping')),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                StatusChip(label: t(status.label), tone: status.tone),
                const SizedBox(width: 12),
                if (order.placedAt != null)
                  Text(
                    t('order.placedAt', {
                      'date': formatDateTime(order.placedAt!),
                    }),
                    style: text.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (order.pickupPoint != null)
              _PickupPointCard(
                point: order.pickupPoint!,
                recipient: order.recipient,
              ),
            for (var i = 0; i < order.groups.length; i++)
              _GroupSection(
                order: order,
                group: order.groups[i],
                index: i,
                total: order.groups.length,
              ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(t('order.total'), style: text.titleSmall),
                        const Spacer(),
                        Text(
                          formatMoney(order.totalAmount, intl),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    if (order.paymentMethod == PaymentMethod.cashOnDelivery)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          t('order.cashNote'),
                          style: text.bodySmall?.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(t(_paymentLabel(order.paymentMethod))),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _paymentLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.payme => 'order.paymentPayme',
  PaymentMethod.click => 'order.paymentClick',
  PaymentMethod.uzcard => 'order.paymentUzcard',
  PaymentMethod.cashOnDelivery => 'checkout.cashAtPoint',
};

class _PickupPointCard extends ConsumerWidget {
  const _PickupPointCard({required this.point, required this.recipient});

  final OrderPickupPointRead point;
  final Recipient recipient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final subtle = text.bodySmall?.copyWith(color: colors.mutedForeground);
    final hours = todaysHours(point.operatingHours);
    final landmark = point.address.landmark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('checkout.pickupPoint'), style: text.titleSmall),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(point.name, style: text.titleSmall),
                      if (point.address.display.isNotEmpty)
                        Text(point.address.display),
                      if (landmark != null) Text(landmark, style: subtle),
                      Text(
                        hours == null
                            ? t('checkout.hoursUnknown')
                            : t('checkout.todayHours', {'hours': hours}),
                        style: subtle,
                      ),
                      if (point.contactPhone.isNotEmpty)
                        Text(
                          t('checkout.pointPhone', {
                            'phone': point.contactPhone,
                          }),
                          style: subtle,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(t('checkout.recipient'), style: text.titleSmall),
            Text('${recipient.fullName}, ${recipient.phone}'),
          ],
        ),
      ),
    );
  }
}

class _GroupSection extends ConsumerStatefulWidget {
  const _GroupSection({
    required this.order,
    required this.group,
    required this.index,
    required this.total,
  });

  final OrderRead order;
  final OrderShopGroupRead group;
  final int index;
  final int total;

  @override
  ConsumerState<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends ConsumerState<_GroupSection> {
  var _cancelling = false;

  Future<void> _cancel() async {
    final t = ref.read(tProvider);
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ref
          .read(orderRepositoryProvider)
          .cancelGroup(widget.order.id, widget.group.id, reason: reason);
      // The order's status is computed from its groups: reload it.
      ref.invalidate(orderProvider(widget.order.id));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error, t('cancel.failed')))),
        );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final intl = ref.watch(settingsProvider.select((s) => s.locale.intlTag));
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final group = widget.group;
    final status = groupStatusInfo(group.status);
    final progress = groupProgress(group.status);
    final subtle = text.bodySmall?.copyWith(color: colors.mutedForeground);
    // Only ask for the deadline once the group is at the point (else it is a 404).
    final pickup = group.hasReachedPoint
        ? ref
              .watch(
                pickupStatusProvider((
                  orderId: widget.order.id,
                  groupId: group.id,
                )),
              )
              .value
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.total > 1
                        ? '${group.shop.name} · ${t('order.shipmentOf', {'index': widget.index + 1, 'total': widget.total})}'
                        : group.shop.name,
                    style: text.titleSmall,
                  ),
                ),
                StatusChip(label: t(status.label), tone: status.tone),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              DeliveryTracker(progress: progress),
            ],
            if (pickup != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  t('order.readyUntil', {
                    'date': formatDateTime(pickup.collectionDeadline),
                  }),
                  style: TextStyle(color: colors.success),
                ),
              ),
            if (group.status == OrderShopGroupStatus.cancelled &&
                group.cancellationReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  t('order.cancelReason', {
                    'reason': group.cancellationReason!,
                  }),
                  style: subtle,
                ),
              ),
            const Divider(height: 24),
            for (final line in group.lines)
              _LineRow(orderId: widget.order.id, line: line, intl: intl),
            if (group.canCancel) ...[
              const SizedBox(height: 8),
              Text(t('cancel.hint'), style: subtle),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _cancelling ? null : _cancel,
                child: Text(
                  _cancelling ? t('cancel.cancelling') : t('cancel.button'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineRow extends ConsumerWidget {
  const _LineRow({
    required this.orderId,
    required this.line,
    required this.intl,
  });

  final int orderId;
  final OrderLineRead line;
  final String intl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final variant = line.variantAttributes?.values.join(' / ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: ProductImage(line.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.productTitleSnapshot,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (variant != null && variant.isNotEmpty)
                      Text(
                        variant,
                        style: text.bodySmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    Text(
                      '${line.quantity} × ${formatMoney(line.unitPrice, intl)}',
                      style: text.bodySmall?.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(line.lineTotal, intl),
                style: text.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          _ReturnArea(orderId: orderId, line: line),
        ],
      ),
    );
  }
}

/// What the buyer can do about returning one line, and where a return stands. The rules
/// are `OrderLineRead.returnState` (docs/orders-and-payments-api.md §4).
class _ReturnArea extends ConsumerStatefulWidget {
  const _ReturnArea({required this.orderId, required this.line});

  final int orderId;
  final OrderLineRead line;

  @override
  ConsumerState<_ReturnArea> createState() => _ReturnAreaState();
}

class _ReturnAreaState extends ConsumerState<_ReturnArea> {
  var _busy = false;

  Future<void> _request() async {
    final t = ref.read(tProvider);
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showReturnSheet(context, widget.line);
    if (!sent) return;
    ref.invalidate(orderProvider(widget.orderId));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('return.sent'))));
  }

  /// Once per request; the team's decision is final.
  Future<void> _escalate(int refundId) async {
    final t = ref.read(tProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(orderRepositoryProvider).escalate(refundId);
      ref.invalidate(orderProvider(widget.orderId));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t('return.escalated'))));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(error, t('return.escalateFailed'))),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final colors = AppColors.of(context);
    final subtle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: colors.mutedForeground);
    final line = widget.line;
    final request = line.refundRequest;
    Widget note(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: subtle?.copyWith(color: color)),
    );

    switch (line.returnState()) {
      case ReturnState.none:
        return const SizedBox.shrink();
      case ReturnState.canRequest:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (line.returnDeadline != null)
              note(
                t('return.deadline', {
                  'date': formatDate(line.returnDeadline!),
                }),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _request,
                child: Text(t('return.button')),
              ),
            ),
          ],
        );
      case ReturnState.requested:
        return note(t('return.requested'));
      case ReturnState.rejectedCanEscalate || ReturnState.rejectedFinal:
        final canEscalate =
            line.returnState() == ReturnState.rejectedCanEscalate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            note(t('return.rejected'), color: colors.destructive),
            if (request?.resolutionNote != null)
              note(
                t('return.rejectedReason', {
                  'reason': request!.resolutionNote!,
                }),
              ),
            if (canEscalate && request != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _busy ? null : () => _escalate(request.id),
                  child: Text(t('return.escalate')),
                ),
              )
            else
              note(t('return.final')),
          ],
        );
      case ReturnState.returnPending:
        final point = request?.returnPoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (point != null)
              note(
                t('return.bringTo', {'name': point.name}),
                color: colors.foreground,
              ),
            if (point != null && point.address.display.isNotEmpty)
              note(point.address.display),
            note(t('return.bringHint')),
          ],
        );
      case ReturnState.returnedToPoint:
        return note(t('return.handedIn'));
      case ReturnState.refunded:
        return note(t('return.refunded'), color: colors.success);
    }
  }
}

/// Reason picker for cancelling one shipment; pops the reason text the shop will see.
class _CancelDialog extends ConsumerStatefulWidget {
  const _CancelDialog();

  @override
  ConsumerState<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends ConsumerState<_CancelDialog> {
  var _reason = cancelReasons.first;
  final _details = TextEditingController();
  var _missing = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  bool get _isOther => _reason == cancelReasons.last;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return AlertDialog(
      title: Text(t('cancel.title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('cancel.body')),
            const SizedBox(height: 12),
            Text(
              t('cancel.reason'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value ?? _reason),
              child: Column(
                children: [
                  for (final key in cancelReasons)
                    RadioListTile<String>(
                      value: key,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t(key)),
                    ),
                ],
              ),
            ),
            if (_isOther)
              TextField(
                controller: _details,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: t('cancel.details'),
                  errorText: _missing ? t('cancel.details') : null,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('cancel.keep')),
        ),
        FilledButton(
          onPressed: () {
            final text = _isOther ? _details.text.trim() : t(_reason);
            if (text.isEmpty) {
              setState(() => _missing = true);
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: Text(t('cancel.confirm')),
        ),
      ],
    );
  }
}
