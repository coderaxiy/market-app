// Mirrors openapi/api.yaml -> RefundRequestRead, RefundRequestSummaryRead, RefundEvidenceRead,
// RefundRequestCreate, RefundReasonCode, RefundStatus, RefundRequestedBy, WhoBearsCost.
// Guide: sdk-contract/docs/orders-and-payments-api.md §1 "Refunds are all-or-nothing", §4.

import '../../catalog/data/common.dart';
import 'order.dart';

enum RefundReasonCode {
  defective('defective'),
  notAsDescribed('not_as_described'),
  wrongItem('wrong_item'),
  changedMind('changed_mind'),
  neverArrived('never_arrived'),
  other('other');

  const RefundReasonCode(this.wire);

  final String wire;

  static RefundReasonCode parse(String value) => values.firstWhere(
    (code) => code.wire == value,
    orElse: () => throw FormatException('Unknown RefundReasonCode: $value'),
  );
}

/// New values may appear: unknown ones read as [unknown], render them gracefully.
enum RefundStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  escalatedToAdmin('escalated_to_admin'),
  unknown('');

  const RefundStatus(this.wire);

  final String wire;

  static RefundStatus parse(String value) => values.firstWhere(
    (status) => status.wire == value && status != unknown,
    orElse: () => unknown,
  );
}

enum WhoBearsCost { seller, platform }

class RefundEvidenceRead {
  const RefundEvidenceRead({required this.key, required this.url});

  factory RefundEvidenceRead.fromJson(Json json) => RefundEvidenceRead(
    key: json['key'] as String,
    url: json['url'] as String,
  );

  final String key;

  /// Signed, valid 15 minutes: display it, never store it.
  final String url;
}

/// `OrderLineRead.refund_request`: the line's latest request.
class RefundRequestSummaryRead {
  const RefundRequestSummaryRead({
    required this.id,
    required this.status,
    required this.reasonCode,
    required this.createdAt,
    this.resolvedAt,
    this.escalatedAt,
    this.resolutionNote,
    this.returnPoint,
    this.pointReceivedAt,
  });

  factory RefundRequestSummaryRead.fromJson(Json json) =>
      RefundRequestSummaryRead(
        id: json['id'] as int,
        status: RefundStatus.parse(json['status'] as String),
        reasonCode: RefundReasonCode.parse(json['reason_code'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        resolvedAt: _date(json['resolved_at']),
        escalatedAt: _date(json['escalated_at']),
        resolutionNote: json['resolution_note'] as String?,
        returnPoint: json['return_point'] == null
            ? null
            : OrderPickupPointRead.fromJson(json['return_point'] as Json),
        pointReceivedAt: _date(json['point_received_at']),
      );

  final int id;
  final RefundStatus status;
  final RefundReasonCode reasonCode;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  /// Set once the buyer escalated; only possible once.
  final DateTime? escalatedAt;

  /// The reason when rejected: show it before offering "escalate".
  final String? resolutionNote;

  /// The point to bring the item to, only while the line is `return_pending`.
  final OrderPickupPointRead? returnPoint;

  /// When pickup staff took the item in.
  final DateTime? pointReceivedAt;
}

/// The full request, from `POST /order-lines/{id}/refund-request`, `GET` and `escalate`.
class RefundRequestRead {
  const RefundRequestRead({
    required this.id,
    required this.orderLineId,
    required this.requestedBy,
    required this.reasonCode,
    required this.status,
    required this.refundAmount,
    required this.evidence,
    required this.createdAt,
    this.reasonText,
    this.whoBearsCost,
    this.resolvedAt,
    this.escalatedAt,
    this.resolutionNote,
    this.pointReceivedAt,
  });

  factory RefundRequestRead.fromJson(Json json) => RefundRequestRead(
    id: json['id'] as int,
    orderLineId: json['order_line_id'] as int,
    requestedBy: json['requested_by'] as String,
    reasonCode: RefundReasonCode.parse(json['reason_code'] as String),
    reasonText: json['reason_text'] as String?,
    status: RefundStatus.parse(json['status'] as String),
    refundAmount: json['refund_amount'] as String,
    whoBearsCost: json['who_bears_cost'] == null
        ? null
        : WhoBearsCost.values.byName(json['who_bears_cost'] as String),
    evidence: readList(json['evidence'], RefundEvidenceRead.fromJson),
    resolvedAt: _date(json['resolved_at']),
    escalatedAt: _date(json['escalated_at']),
    resolutionNote: json['resolution_note'] as String?,
    pointReceivedAt: _date(json['point_received_at']),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final int orderLineId;

  /// `buyer`, `seller` or `admin`. Only buyer-made requests are shown in the app.
  final String requestedBy;
  final RefundReasonCode reasonCode;
  final String? reasonText;
  final RefundStatus status;

  /// Always the line's full `line_total`: there is no amount to enter.
  final Money refundAmount;

  /// Null until approved. Buyers don't need to show it.
  final WhoBearsCost? whoBearsCost;

  /// Signed 15-minute URLs. (`evidence_urls` is a legacy field and is not read.)
  final List<RefundEvidenceRead> evidence;
  final DateTime? resolvedAt;
  final DateTime? escalatedAt;
  final String? resolutionNote;
  final DateTime? pointReceivedAt;
  final DateTime createdAt;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// What the buyer can do with one order line, from docs/orders-and-payments-api.md §4
/// "Reading a line's return state". Computed by `OrderLineRead.returnState`.
enum ReturnState {
  /// Nothing to offer: not delivered yet, or the return window closed.
  none,

  /// Show "Return this item".
  canRequest,

  /// A request is `pending` or `escalated_to_admin`: show "Return requested".
  requested,

  /// Rejected, never escalated: show the note and offer "Escalate" (once).
  rejectedCanEscalate,

  /// Rejected and escalated: the admin's decision is final.
  rejectedFinal,

  /// Approved: "Bring the item to {returnPoint.name}"; the money moves when the seller
  /// receives it.
  returnPending,

  /// Handed in at the pickup point; on its way back to the seller. No money yet.
  returnedToPoint,

  /// Refunded in full.
  refunded,
}
