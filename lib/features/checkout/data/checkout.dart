// Mirrors openapi/api.yaml -> CheckoutRequest, Recipient, PaymentMethod, CheckoutResponse.
// The `price_changed` 400 body is documented in docs/orders-and-payments-api.md §2 step 5.

import '../../catalog/data/common.dart';

enum PaymentMethod {
  payme('payme'),
  click('click'),
  uzcard('uzcard'),
  cashOnDelivery('cash_on_delivery');

  const PaymentMethod(this.wire);

  final String wire;

  static PaymentMethod parse(String value) => values.firstWhere(
    (method) => method.wire == value,
    orElse: () => throw FormatException('Unknown PaymentMethod: $value'),
  );
}

enum RecipientField { fullName, phone }

/// Who collects the order at the pickup point. There is no delivery address.
class Recipient {
  const Recipient({required this.fullName, required this.phone, this.notes});

  factory Recipient.fromJson(Json json) => Recipient(
    fullName: json['full_name'] as String,
    phone: json['phone'] as String,
    notes: json['notes'] as String?,
  );

  /// 1-255 chars.
  final String fullName;

  /// 5-30 chars. The pickup point checks it when the buyer collects.
  final String phone;
  final String? notes;

  /// Fields that would get a `422`, checked before sending.
  Set<RecipientField> get invalidFields => {
    if (fullName.trim().isEmpty || fullName.trim().length > 255)
      RecipientField.fullName,
    if (phone.trim().length < 5 || phone.trim().length > 30)
      RecipientField.phone,
  };

  Json toJson() {
    final note = notes?.trim();
    return {
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'notes': note == null || note.isEmpty ? null : note,
    };
  }
}

class CheckoutResponse {
  const CheckoutResponse({
    required this.orderId,
    required this.orderNumber,
    this.paymentRedirectUrl,
  });

  factory CheckoutResponse.fromJson(Json json) => CheckoutResponse(
    orderId: json['order_id'] as int,
    orderNumber: json['order_number'] as String,
    paymentRedirectUrl: json['payment_redirect_url'] as String?,
  );

  final int orderId;
  final String orderNumber;

  /// Null for cash on delivery (the order is already confirmed). Online gateways aren't
  /// connected yet: the URL is a placeholder.
  final String? paymentRedirectUrl;
}

class PriceChange {
  const PriceChange({
    required this.productId,
    required this.oldPrice,
    required this.newPrice,
    this.variantId,
  });

  factory PriceChange.fromJson(Json json) => PriceChange(
    productId: json['product_id'] as int,
    variantId: json['variant_id'] as int?,
    oldPrice: json['old_price'] as String,
    newPrice: json['new_price'] as String,
  );

  final int productId;
  final int? variantId;
  final Money oldPrice;
  final Money newPrice;
}

/// `POST /checkout` answered `400 price_changed`: a price moved since the item was added.
/// Show old vs new, and on confirm call `CartController.acceptPriceChanges()` then retry.
class PriceChangedException implements Exception {
  const PriceChangedException(this.items);

  final List<PriceChange> items;
}
