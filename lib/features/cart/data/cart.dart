// Mirrors openapi/api.yaml -> CartRead, CartItemRead, CartProductRead, CartVariantRead,
// CartStatus. Guide: sdk-contract/docs/orders-and-payments-api.md §3.1 (incl. guest cart)
// and §4.

import '../../../core/format.dart';
import '../../catalog/data/common.dart';

enum CartStatus {
  active,
  checkedOut,
  abandoned;

  static CartStatus parse(String value) => switch (value) {
    'active' => active,
    'checked_out' => checkedOut,
    'abandoned' => abandoned,
    _ => throw FormatException('Unknown CartStatus: $value'),
  };
}

class CartProductRead {
  const CartProductRead({
    required this.id,
    required this.slug,
    required this.title,
    this.imageUrl,
  });

  factory CartProductRead.fromJson(Json json) => CartProductRead(
    id: json['id'] as int,
    slug: json['slug'] as String,
    title: json['title'] as String,
    imageUrl: json['image_url'] as String?,
  );

  final int id;
  final String slug;
  final String title;
  final String? imageUrl;
}

class CartVariantRead {
  const CartVariantRead({required this.id, required this.attributes});

  factory CartVariantRead.fromJson(Json json) => CartVariantRead(
    id: json['id'] as int,
    attributes: Map<String, Object>.from(json['attributes'] as Json),
  );

  final int id;

  /// Values are `String`, `num` or `bool`.
  final Map<String, Object> attributes;
}

class CartItemRead {
  const CartItemRead({
    required this.id,
    required this.quantity,
    required this.addedAt,
    required this.product,
    required this.shop,
    required this.priceSnapshot,
    required this.unitPrice,
    required this.lineTotal,
    required this.available,
    required this.inStock,
    this.variant,
  });

  factory CartItemRead.fromJson(Json json) => CartItemRead(
    id: json['id'] as int,
    quantity: json['quantity'] as int,
    addedAt: DateTime.parse(json['added_at'] as String),
    product: CartProductRead.fromJson(json['product'] as Json),
    variant: json['variant'] == null
        ? null
        : CartVariantRead.fromJson(json['variant'] as Json),
    shop: ShopSummaryRead.fromJson(json['shop'] as Json),
    priceSnapshot: json['price_snapshot'] as String,
    unitPrice: json['unit_price'] as String,
    lineTotal: json['line_total'] as String,
    available: json['available'] as bool,
    inStock: json['in_stock'] as bool,
  );

  final int id;
  final int quantity;
  final DateTime addedAt;
  final CartProductRead product;
  final CartVariantRead? variant;
  final ShopSummaryRead shop;

  /// Price when added, or when the quantity was last PATCHed.
  final Money priceSnapshot;

  /// Current price: what checkout will charge.
  final Money unitPrice;
  final Money lineTotal;

  /// False when the product, its shop or its variant can't be bought any more.
  final bool available;
  final bool inStock;

  /// The price moved since the buyer last confirmed it. Checkout answers
  /// `price_changed` until each such line is PATCHed with its current quantity.
  bool get priceChanged => toTiyin(priceSnapshot) != toTiyin(unitPrice);
}

class CartRead {
  const CartRead({
    required this.id,
    required this.status,
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CartRead.fromJson(Json json) => CartRead(
    id: json['id'] as int,
    status: CartStatus.parse(json['status'] as String),
    items: readList(json['items'], CartItemRead.fromJson),
    itemCount: json['item_count'] as int,
    subtotal: json['subtotal'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  final int id;
  final CartStatus status;

  /// Ordered by `addedAt`.
  final List<CartItemRead> items;

  /// Sum of quantities over all lines, for the tab badge.
  final int itemCount;

  /// Sum of `lineTotal` over available lines only.
  final Money subtotal;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<CartItemRead> get priceChangedItems => [
    for (final item in items)
      if (item.available && item.priceChanged) item,
  ];

  bool get hasUnavailableItems => items.any((item) => !item.available);
}
