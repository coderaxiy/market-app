// Buyer-facing wording and rules for orders and their per-shop groups, ported from the
// storefront's `src/lib/orders.ts`. docs/orders-and-payments-api.md §1.

import '../data/order.dart';

enum Tone { accent, success, warning, destructive, neutral }

/// Status label (translation key) and tone for an order. Cash-on-delivery orders are `paid`
/// right after checkout: "confirmed" is what's true for the buyer.
({String label, Tone tone}) orderStatusInfo(
  OrderStatus status,
) => switch (status) {
  OrderStatus.pendingPayment => (
    label: 'order.statusPendingPayment',
    tone: Tone.warning,
  ),
  OrderStatus.paid => (label: 'order.statusConfirmed', tone: Tone.accent),
  OrderStatus.partiallyFulfilled => (
    label: 'order.statusPartlyCollected',
    tone: Tone.accent,
  ),
  OrderStatus.completed => (label: 'order.statusCompleted', tone: Tone.success),
  OrderStatus.cancelled => (label: 'order.statusCancelled', tone: Tone.neutral),
  OrderStatus.paymentFailed => (
    label: 'order.statusPaymentFailed',
    tone: Tone.destructive,
  ),
  OrderStatus.unknown => (label: 'order.groupUnknown', tone: Tone.neutral),
};

enum OrderTab { all, active, completed, cancelled }

/// The tab an order belongs to.
OrderTab orderTab(OrderStatus status) => switch (status) {
  OrderStatus.completed => OrderTab.completed,
  OrderStatus.cancelled || OrderStatus.paymentFailed => OrderTab.cancelled,
  _ => OrderTab.active,
};

/// The `status` filter of `GET /orders` for a tab; empty = all. An unknown status never
/// matches a tab filter, but it still shows under "All".
List<OrderStatus> statusesForTab(OrderTab tab) => switch (tab) {
  OrderTab.all => const [],
  OrderTab.active => const [
    OrderStatus.pendingPayment,
    OrderStatus.paid,
    OrderStatus.partiallyFulfilled,
  ],
  OrderTab.completed => const [OrderStatus.completed],
  OrderTab.cancelled => const [
    OrderStatus.cancelled,
    OrderStatus.paymentFailed,
  ],
};

String orderTabLabel(OrderTab tab) => switch (tab) {
  OrderTab.all => 'orders.tabAll',
  OrderTab.active => 'orders.tabActive',
  OrderTab.completed => 'orders.tabCompleted',
  OrderTab.cancelled => 'orders.tabCancelled',
};

/// The delivery tracker's steps, in order. A group has completed [groupProgress] of them.
const groupSteps = [
  'order.stepConfirmed',
  'order.stepPreparing',
  'order.stepAtWarehouse',
  'order.stepOnTheWay',
  'order.stepAtPoint',
  'order.stepCollected',
];

({String label, Tone tone, int? progress}) _group(
  OrderShopGroupStatus status,
) => switch (status) {
  OrderShopGroupStatus.pending => (
    label: 'order.groupPending',
    tone: Tone.warning,
    progress: 0,
  ),
  OrderShopGroupStatus.confirmed => (
    label: 'order.groupConfirmed',
    tone: Tone.accent,
    progress: 1,
  ),
  OrderShopGroupStatus.preparing => (
    label: 'order.groupPreparing',
    tone: Tone.accent,
    progress: 2,
  ),
  OrderShopGroupStatus.atWarehouse => (
    label: 'order.groupAtWarehouse',
    tone: Tone.accent,
    progress: 3,
  ),
  OrderShopGroupStatus.shipped => (
    label: 'order.groupShipped',
    tone: Tone.accent,
    progress: 4,
  ),
  OrderShopGroupStatus.arrivedAtPoint => (
    label: 'order.groupReady',
    tone: Tone.success,
    progress: 5,
  ),
  OrderShopGroupStatus.partiallyCollected => (
    label: 'order.groupPartlyCollected',
    tone: Tone.success,
    progress: 5,
  ),
  OrderShopGroupStatus.delivered => (
    label: 'order.groupCollected',
    tone: Tone.success,
    progress: 6,
  ),
  OrderShopGroupStatus.returnRequested => (
    label: 'order.groupReturnRequested',
    tone: Tone.warning,
    progress: 6,
  ),
  OrderShopGroupStatus.partiallyRefunded => (
    label: 'order.groupPartlyRefunded',
    tone: Tone.neutral,
    progress: 6,
  ),
  OrderShopGroupStatus.refunded => (
    label: 'order.groupRefunded',
    tone: Tone.neutral,
    progress: 6,
  ),
  // Off the happy path: no tracker.
  OrderShopGroupStatus.cancelled => (
    label: 'order.groupCancelled',
    tone: Tone.neutral,
    progress: null,
  ),
  OrderShopGroupStatus.rejectedByBuyer => (
    label: 'order.groupRejected',
    tone: Tone.neutral,
    progress: null,
  ),
  OrderShopGroupStatus.returnToSeller => (
    label: 'order.groupReturnedToShop',
    tone: Tone.neutral,
    progress: null,
  ),
  OrderShopGroupStatus.unknown => (
    label: 'order.groupUnknown',
    tone: Tone.neutral,
    progress: null,
  ),
};

({String label, Tone tone}) groupStatusInfo(OrderShopGroupStatus status) {
  final info = _group(status);
  return (label: info.label, tone: info.tone);
}

/// Completed tracker steps (0 to 6), or null when the group left the happy path.
int? groupProgress(OrderShopGroupStatus status) => _group(status).progress;

enum TrackerStep { done, current, upcoming }

TrackerStep trackerStep(int index, int progress) => index < progress
    ? TrackerStep.done
    : index == progress
    ? TrackerStep.current
    : TrackerStep.upcoming;

int orderItemCount(OrderRead order) => order.groups.fold(
  0,
  (sum, group) =>
      sum + group.lines.fold(0, (count, line) => count + line.quantity),
);

/// The reasons offered when cancelling a shipment (the last one asks for free text).
const cancelReasons = [
  'cancel.reasonChangedMind',
  'cancel.reasonMistake',
  'cancel.reasonTooLong',
  'cancel.reasonOther',
];
