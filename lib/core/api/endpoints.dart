// Every API path lives here, grouped per resource. Paths are relative to the client's
// base URL, which already includes `/api/v1`. Never hardcode a path elsewhere.

String _seg(String value) => Uri.encodeComponent(value);

abstract final class AuthEndpoints {
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const changePassword = '/auth/me/password';
  static const passwordResetRequest = '/auth/password-reset/request';
  static const passwordResetConfirm = '/auth/password-reset/confirm';
}

/// Public, no auth. docs/storefront-catalog-api.md
abstract final class CatalogEndpoints {
  /// `ProductCardRead[]`; total in the `X-Total-Count` header.
  static const products = '/products';
  static const facets = '/products/facets';
  static const categories = '/categories';
  static const brands = '/brands';

  static String product(int productId) => '/products/$productId';

  static String productBySlug(String shopSlug, String productSlug) =>
      '/shops/by-slug/${_seg(shopSlug)}/products/${_seg(productSlug)}';

  static String categoryAttributes(int categoryId) =>
      '/categories/$categoryId/attributes';

  static String shopBySlug(String shopSlug) =>
      '/shops/by-slug/${_seg(shopSlug)}';
}

/// Works logged out too (guest cart via the `cart_token` cookie).
abstract final class CartEndpoints {
  static const cart = '/cart';
  static const items = '/cart/items';

  static String item(int cartItemId) => '/cart/items/$cartItemId';
}

/// Login required, except `nearby`. docs/logistics-and-pickup-points-api.md §3.4
abstract final class PickupEndpoints {
  static const regions = '/regions';

  /// `?region_id=`; active points only.
  static const pickupPoints = '/pickup-points';

  /// `PickupPointRead | null`: the point on the buyer's previous order.
  static const lastUsed = '/pickup-points/last-used';

  /// Public. `?lat=&lng=&radius_km=`
  static const nearby = '/pickup-points/nearby';
}

/// docs/orders-and-payments-api.md §2, §3.1
abstract final class OrderEndpoints {
  static const checkout = '/checkout';
  static const orders = '/orders';

  static String order(int orderId) => '/orders/$orderId';

  /// `{ reason }`; only while the group is `pending` or `confirmed`.
  static String cancelGroup(int orderId, int groupId) =>
      '/orders/$orderId/groups/$groupId/cancel';

  /// `404` until the group reaches the pickup point: that means "still on the way".
  static String pickupStatus(int orderId, int groupId) =>
      '/orders/$orderId/groups/$groupId/pickup-status';
}
