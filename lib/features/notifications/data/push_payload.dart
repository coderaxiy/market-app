// The `data` map of a push, documented in sdk-contract/docs/notifications-api.md "Events".
// All values arrive as strings (`order_id: "12"`).

enum PushEventType {
  arrivedAtPoint('order_group.arrived_at_point'),
  groupCancelled('order_group.cancelled'),
  refundApproved('refund.approved'),
  refundRejected('refund.rejected'),

  /// A type this app version doesn't know: open the app, nothing more.
  unknown('');

  const PushEventType(this.wire);

  final String wire;

  static PushEventType parse(String? value) => values.firstWhere(
    (type) => type.wire == value && type != unknown,
    orElse: () => unknown,
  );
}

class PushPayload {
  const PushPayload({
    required this.type,
    this.orderId,
    this.groupId,
    this.refundRequestId,
    this.collectionDeadline,
  });

  factory PushPayload.fromData(Map<String, dynamic> data) => PushPayload(
    type: PushEventType.parse(data['type'] as String?),
    orderId: _int(data['order_id']),
    groupId: _int(data['group_id']),
    refundRequestId: _int(data['refund_request_id']),
    collectionDeadline: data['collection_deadline'] is String
        ? DateTime.tryParse(data['collection_deadline'] as String)
        : null,
  );

  final PushEventType type;
  final int? orderId;
  final int? groupId;

  /// Refund events only.
  final int? refundRequestId;

  /// `arrivedAtPoint` only, UTC. The push text shows it in Uzbekistan time (UTC+5).
  final DateTime? collectionDeadline;

  /// Every documented event opens the order; null when the payload has no usable id.
  int? get openOrderId => type == PushEventType.unknown ? null : orderId;
}

int? _int(Object? value) => value is String ? int.tryParse(value) : null;
