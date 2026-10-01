// Mirrors openapi/api.yaml -> OrderRead, OrderShopGroupRead, OrderLineRead,
// OrderPickupPointRead, OrderStatus, OrderShopGroupStatus, OrderLineStatus, PickupStatusRead.
// Guide: sdk-contract/docs/orders-and-payments-api.md §1, §4 and
// logistics-and-pickup-points-api.md.

import '../../catalog/data/common.dart';
import '../../checkout/data/checkout.dart';
import '../../logistics/data/pickup_point.dart';
import 'refund.dart';

/// Enums below read an unknown value as `unknown` instead of failing: the backend may add
/// statuses, and an old app should still show the order.
enum OrderStatus {
  pendingPayment('pending_payment'),
  paid('paid'),
  partiallyFulfilled('partially_fulfilled'),
  completed('completed'),
  cancelled('cancelled'),
  paymentFailed('payment_failed'),
  unknown('');

  const OrderStatus(this.wire);

  final String wire;

  static OrderStatus parse(String value) => values.firstWhere(
    (status) => status.wire == value && status != unknown,
    orElse: () => unknown,
  );
}

enum OrderShopGroupStatus {
  pending('pending'),
  confirmed('confirmed'),
  preparing('preparing'),

  /// The central store received the goods.
  atWarehouse('at_warehouse'),

  /// On the way from the central store to the buyer's pickup point.
  shipped('shipped'),
  arrivedAtPoint('arrived_at_point'),
  partiallyCollected('partially_collected'),
  delivered('delivered'),
  cancelled('cancelled'),
  returnRequested('return_requested'),
  partiallyRefunded('partially_refunded'),
  refunded('refunded'),
  rejectedByBuyer('rejected_by_buyer'),
  returnToSeller('return_to_seller'),
  unknown('');

  const OrderShopGroupStatus(this.wire);

  final String wire;

  static OrderShopGroupStatus parse(String value) => values.firstWhere(
    (status) => status.wire == value && status != unknown,
    orElse: () => unknown,
  );
}

enum OrderLineStatus {
  active('active'),

  /// Refund approved: send the item back; refunded when the seller receives it.
  returnPending('return_pending'),

  /// Handed in at the pickup point; no money has moved yet.
  returnedToPoint('returned_to_point'),
  refunded('refunded'),
  unknown('');

  const OrderLineStatus(this.wire);

  final String wire;

  static OrderLineStatus parse(String value) => values.firstWhere(
    (status) => status.wire == value && status != unknown,
    orElse: () => unknown,
  );
}

class OrderPickupPointRead {
  const OrderPickupPointRead({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.operatingHours,
    required this.contactPhone,
  });

  factory OrderPickupPointRead.fromJson(Json json) => OrderPickupPointRead(
    id: json['id'] as int,
    name: json['name'] as String,
    address: PickupPointAddress(json['address'] as Json),
    latitude: double.parse(json['latitude'] as String),
    longitude: double.parse(json['longitude'] as String),
    operatingHours: json['operating_hours'] as Json,
    contactPhone: json['contact_phone'] as String,
  );

  final int id;
  final String name;
  final PickupPointAddress address;
  final double latitude;
  final double longitude;
  final Json operatingHours;
  final String contactPhone;
}

class OrderLineRead {
  const OrderLineRead({
    required this.id,
    required this.productId,
    required this.productTitleSnapshot,
    required this.platformSkuSnapshot,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.status,
    required this.createdAt,
    this.variantId,
    this.physicalReturnReceivedAt,
    this.imageUrl,
    this.variantAttributes,
    this.productSlug,
    this.returnDeadline,
    this.refundRequest,
  });

  factory OrderLineRead.fromJson(Json json) => OrderLineRead(
    id: json['id'] as int,
    productId: json['product_id'] as int,
    variantId: json['variant_id'] as int?,
    productTitleSnapshot: json['product_title_snapshot'] as String,
    platformSkuSnapshot: json['platform_sku_snapshot'] as String,
    unitPrice: json['unit_price'] as String,
    quantity: json['quantity'] as int,
    lineTotal: json['line_total'] as String,
    status: OrderLineStatus.parse(json['status'] as String),
    physicalReturnReceivedAt: _date(json['physical_return_received_at']),
    createdAt: DateTime.parse(json['created_at'] as String),
    imageUrl: json['image_url'] as String?,
    variantAttributes: json['variant_attributes'] == null
        ? null
        : Map<String, Object>.from(json['variant_attributes'] as Json),
    productSlug: json['product_slug'] as String?,
    returnDeadline: _date(json['return_deadline']),
    refundRequest: json['refund_request'] == null
        ? null
        : RefundRequestSummaryRead.fromJson(json['refund_request'] as Json),
  );

  final int id;
  final int productId;
  final int? variantId;

  /// Frozen at purchase: may differ from the live product now.
  final String productTitleSnapshot;

  /// Frozen platform SKU: what the store and pickup points match on ("Article").
  final String platformSkuSnapshot;
  final Money unitPrice;
  final int quantity;
  final Money lineTotal;
  final OrderLineStatus status;
  final DateTime? physicalReturnReceivedAt;
  final DateTime createdAt;

  /// The variant's first image, else the product's primary (current, not a snapshot).
  final String? imageUrl;

  /// The variant's current attributes; null for non-variant products.
  final Map<String, Object>? variantAttributes;

  /// Current slug; null when the product isn't visible any more (hide the link).
  final String? productSlug;

  /// Last moment a refund can be requested; null until the group is delivered.
  final DateTime? returnDeadline;

  /// The line's latest request; null if it never had one.
  final RefundRequestSummaryRead? refundRequest;

  /// What the buyer can do with this line. [now] is injectable for tests.
  ReturnState returnState([DateTime? now]) {
    final request = refundRequest;
    switch (status) {
      case OrderLineStatus.refunded:
        return ReturnState.refunded;
      case OrderLineStatus.returnPending:
        return ReturnState.returnPending;
      case OrderLineStatus.returnedToPoint:
        return ReturnState.returnedToPoint;
      case OrderLineStatus.active || OrderLineStatus.unknown:
        break;
    }
    if (request != null) {
      switch (request.status) {
        case RefundStatus.pending || RefundStatus.escalatedToAdmin:
          return ReturnState.requested;
        case RefundStatus.rejected:
          if (request.escalatedAt == null) {
            return ReturnState.rejectedCanEscalate;
          }
          // Escalated and rejected: final for escalating, but a new request is allowed.
          break;
        case RefundStatus.approved || RefundStatus.unknown:
          break;
      }
    }
    final deadline = returnDeadline;
    final open = deadline != null && (now ?? DateTime.now()).isBefore(deadline);
    if (!open) {
      return request?.status == RefundStatus.rejected
          ? ReturnState.rejectedFinal
          : ReturnState.none;
    }
    return ReturnState.canRequest;
  }
}

class OrderShopGroupRead {
  const OrderShopGroupRead({
    required this.id,
    required this.orderId,
    required this.shopId,
    required this.status,
    required this.subtotal,
    required this.shippingFee,
    required this.shop,
    required this.lines,
    required this.createdAt,
    required this.updatedAt,
    this.cancellationReason,
    this.warehouseReceivedAt,
    this.deliveredAt,
  });

  factory OrderShopGroupRead.fromJson(Json json) => OrderShopGroupRead(
    id: json['id'] as int,
    orderId: json['order_id'] as int,
    shopId: json['shop_id'] as int,
    status: OrderShopGroupStatus.parse(json['status'] as String),
    subtotal: json['subtotal'] as String,
    shippingFee: json['shipping_fee'] as String,
    cancellationReason: json['cancellation_reason'] as String?,
    warehouseReceivedAt: _date(json['warehouse_received_at']),
    deliveredAt: _date(json['delivered_at']),
    shop: ShopSummaryRead.fromJson(json['shop'] as Json),
    lines: readList(json['lines'], OrderLineRead.fromJson),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  final int id;
  final int orderId;
  final int shopId;
  final OrderShopGroupStatus status;
  final Money subtotal;

  /// Currently always "0.00".
  final Money shippingFee;
  final String? cancellationReason;

  /// When the central store received it.
  final DateTime? warehouseReceivedAt;

  /// When the buyer finished collecting.
  final DateTime? deliveredAt;

  /// The shop's current name and logo, not a snapshot.
  final ShopSummaryRead shop;
  final List<OrderLineRead> lines;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Free cancellation only while the seller hasn't started preparing it. Check this
  /// client-side: a later cancel is a 400.
  bool get canCancel =>
      status == OrderShopGroupStatus.pending ||
      status == OrderShopGroupStatus.confirmed;

  /// Worth asking `GET .../pickup-status` for: the group has reached the pickup point.
  bool get hasReachedPoint =>
      status == OrderShopGroupStatus.arrivedAtPoint ||
      status == OrderShopGroupStatus.partiallyCollected;
}

class OrderRead {
  const OrderRead({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.recipient,
    required this.paymentMethod,
    required this.groups,
    required this.createdAt,
    required this.updatedAt,
    this.pickupPoint,
    this.paymentReference,
    this.placedAt,
  });

  factory OrderRead.fromJson(Json json) => OrderRead(
    id: json['id'] as int,
    orderNumber: json['order_number'] as String,
    status: OrderStatus.parse(json['status'] as String),
    totalAmount: json['total_amount'] as String,
    recipient: Recipient.fromJson(json['recipient'] as Json),
    pickupPoint: json['pickup_point'] == null
        ? null
        : OrderPickupPointRead.fromJson(json['pickup_point'] as Json),
    paymentMethod: PaymentMethod.parse(json['payment_method'] as String),
    paymentReference: json['payment_reference'] as String?,
    placedAt: _date(json['placed_at']),
    groups: readList(json['groups'], OrderShopGroupRead.fromJson),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  final int id;

  /// e.g. "ORD-2026-000123".
  final String orderNumber;

  /// Computed from the groups: re-fetch the order after a group action.
  final OrderStatus status;
  final Money totalAmount;
  final Recipient recipient;

  /// Null only on orders placed before pickup points were required.
  final OrderPickupPointRead? pickupPoint;
  final PaymentMethod paymentMethod;
  final String? paymentReference;
  final DateTime? placedAt;

  /// Show each shop's group separately: fulfillment and refunds happen per group.
  final List<OrderShopGroupRead> groups;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum PickupHoldingStatus {
  holding,
  partiallyCollected,
  collected,
  expiredUncollected;

  static PickupHoldingStatus parse(String value) => switch (value) {
    'holding' => holding,
    'partially_collected' => partiallyCollected,
    'collected' => collected,
    'expired_uncollected' => expiredUncollected,
    _ => throw FormatException('Unknown PickupPointHoldingStatus: $value'),
  };
}

enum PickupHoldingItemStatus {
  holding,
  collected,
  rejectedByBuyer,
  expiredUncollected;

  static PickupHoldingItemStatus parse(String value) => switch (value) {
    'holding' => holding,
    'collected' => collected,
    'rejected_by_buyer' => rejectedByBuyer,
    'expired_uncollected' => expiredUncollected,
    _ => throw FormatException('Unknown PickupPointHoldingItemStatus: $value'),
  };
}

class PickupStatusItemRead {
  const PickupStatusItemRead({
    required this.orderLineId,
    required this.quantity,
    required this.quantityCollected,
    required this.status,
  });

  factory PickupStatusItemRead.fromJson(Json json) => PickupStatusItemRead(
    orderLineId: json['order_line_id'] as int,
    quantity: json['quantity'] as int,
    quantityCollected: json['quantity_collected'] as int,
    status: PickupHoldingItemStatus.parse(json['status'] as String),
  );

  final int orderLineId;
  final int quantity;
  final int quantityCollected;
  final PickupHoldingItemStatus status;
}

/// `GET /orders/{id}/groups/{group_id}/pickup-status`; 404 until the group reaches the point.
class PickupStatusRead {
  const PickupStatusRead({
    required this.orderShopGroupId,
    required this.pickupPointId,
    required this.holdingStatus,
    required this.arrivedAt,
    required this.collectionDeadline,
    required this.items,
  });

  factory PickupStatusRead.fromJson(Json json) => PickupStatusRead(
    orderShopGroupId: json['order_shop_group_id'] as int,
    pickupPointId: json['pickup_point_id'] as int,
    holdingStatus: PickupHoldingStatus.parse(json['holding_status'] as String),
    arrivedAt: DateTime.parse(json['arrived_at'] as String),
    collectionDeadline: DateTime.parse(json['collection_deadline'] as String),
    items: readList(json['items'], PickupStatusItemRead.fromJson),
  );

  final int orderShopGroupId;
  final int pickupPointId;
  final PickupHoldingStatus holdingStatus;
  final DateTime arrivedAt;

  /// Collect by this time, or the items go back to the shop.
  final DateTime collectionDeadline;
  final List<PickupStatusItemRead> items;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
