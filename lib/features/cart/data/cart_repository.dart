import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/endpoints.dart';
import '../../../core/api/providers.dart';
import '../../catalog/data/common.dart';
import 'cart.dart';

/// Works logged out too: without `access_token` the backend uses a guest cart identified
/// by the httpOnly `cart_token` cookie (the client's cookie jar stores it) and merges it
/// on login/register. Errors are `DioException`s: show them with `apiErrorMessage`.
class CartRepository {
  const CartRepository(this._dio);

  final Dio _dio;

  Future<CartRead> fetch() async {
    final response = await _dio.get<Json>(CartEndpoints.cart);
    return CartRead.fromJson(response.data!);
  }

  /// Adding a line already in the cart adds to its quantity (server-side).
  Future<CartItemRead> add({
    required int productId,
    int? variantId,
    int quantity = 1,
  }) async {
    final response = await _dio.post<Json>(
      CartEndpoints.items,
      data: {
        'product_id': productId,
        'variant_id': variantId,
        'quantity': quantity,
      },
    );
    return CartItemRead.fromJson(response.data!);
  }

  /// Sets the quantity. Also moves `price_snapshot` to the current price: that is how a
  /// buyer accepts a changed price.
  Future<CartItemRead> setQuantity(int cartItemId, int quantity) async {
    final response = await _dio.patch<Json>(
      CartEndpoints.item(cartItemId),
      data: {'quantity': quantity},
    );
    return CartItemRead.fromJson(response.data!);
  }

  Future<void> remove(int cartItemId) async {
    await _dio.delete<void>(CartEndpoints.item(cartItemId));
  }
}

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(dioProvider)),
);
