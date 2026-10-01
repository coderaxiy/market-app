import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/providers.dart';
import '../../catalog/data/catalog_repository.dart' show Page;
import '../../catalog/data/common.dart';
import 'order.dart';
import 'refund.dart';

/// Max photos on a refund request (`RefundRequestCreate.evidence_keys`).
const maxRefundEvidence = 5;

/// Login required. Errors are `DioException`s: show them with `apiErrorMessage`.
class OrderRepository {
  const OrderRepository(this._dio);

  final Dio _dio;

  /// The buyer's own orders, all shops, newest first. `limit` default 50, max 100; the
  /// total is in the `X-Total-Count` header. Omit [statuses] for all.
  Future<Page<OrderRead>> orders({
    List<OrderStatus> statuses = const [],
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      OrderEndpoints.orders,
      queryParameters: {
        if (statuses.isNotEmpty) 'status': [for (final s in statuses) s.wire],
        'skip': skip,
        'limit': limit,
      },
    );
    return Page(
      items: readList(response.data, OrderRead.fromJson),
      total: int.tryParse(response.headers.value('x-total-count') ?? ''),
    );
  }

  Future<OrderRead> order(int orderId) async {
    final response = await _dio.get<Json>(OrderEndpoints.order(orderId));
    return OrderRead.fromJson(response.data!);
  }

  /// Only while the group is `pending` or `confirmed` (`OrderShopGroupRead.canCancel`).
  /// Re-fetch the order afterwards: its status is computed from its groups.
  Future<OrderShopGroupRead> cancelGroup(
    int orderId,
    int groupId, {
    required String reason,
  }) async {
    final response = await _dio.post<Json>(
      OrderEndpoints.cancelGroup(orderId, groupId),
      data: {'reason': reason.trim()},
    );
    return OrderShopGroupRead.fromJson(response.data!);
  }

  /// Null while the group hasn't reached the pickup point (the backend answers 404:
  /// that means "still on the way", not an error).
  Future<PickupStatusRead?> pickupStatus(int orderId, int groupId) async {
    try {
      final response = await _dio.get<Json>(
        OrderEndpoints.pickupStatus(orderId, groupId),
      );
      return PickupStatusRead.fromJson(response.data!);
    } on DioException catch (error) {
      if (isNotFound(error)) return null;
      rethrow;
    }
  }

  /// All-or-nothing: the refund is the line's full price, so there is no amount.
  /// [evidenceKeys] come from `UploadRepository.uploadRefundEvidence` (up to
  /// [maxRefundEvidence]). Only a `pending` or `escalated_to_admin` request blocks a new one.
  Future<RefundRequestRead> requestRefund(
    int orderLineId, {
    required RefundReasonCode reasonCode,
    String? reasonText,
    List<String> evidenceKeys = const [],
  }) async {
    if (evidenceKeys.length > maxRefundEvidence) {
      throw ArgumentError.value(
        evidenceKeys.length,
        'evidenceKeys',
        'at most $maxRefundEvidence',
      );
    }
    final text = reasonText?.trim();
    final response = await _dio.post<Json>(
      OrderEndpoints.refundRequest(orderLineId),
      data: {
        'reason_code': reasonCode.wire,
        'reason_text': text == null || text.isEmpty ? null : text,
        'evidence_keys': evidenceKeys.isEmpty ? null : evidenceKeys,
      },
    );
    return RefundRequestRead.fromJson(response.data!);
  }

  Future<RefundRequestRead> refund(int refundId) async {
    final response = await _dio.get<Json>(OrderEndpoints.refund(refundId));
    return RefundRequestRead.fromJson(response.data!);
  }

  /// Once per request, and only on a `rejected` one with `escalatedAt == null`. The
  /// admin's decision is final.
  Future<RefundRequestRead> escalate(int refundId) async {
    final response = await _dio.post<Json>(
      OrderEndpoints.escalateRefund(refundId),
    );
    return RefundRequestRead.fromJson(response.data!);
  }
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(dioProvider)),
);
