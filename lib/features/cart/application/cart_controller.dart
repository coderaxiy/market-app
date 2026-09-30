import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../auth/data/auth_repository.dart';
import '../data/cart.dart';
import '../data/cart_repository.dart';

/// The current cart. Reloads whenever the session changes: login and register merge the
/// guest cart into the user's, logout switches back to a guest cart.
///
/// Mutations throw the `DioException` (show `apiErrorMessage` as a toast) and leave the
/// last known cart in place. After a successful one the whole cart is refetched, since
/// the item endpoints return only the line.
class CartController extends AsyncNotifier<CartRead> {
  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  Future<CartRead> build() async {
    // Wait for the session check, or a logged-in user's first load would hit the guest cart.
    try {
      await ref.watch(sessionProvider.future);
    } catch (_) {
      // A failed session check is not a cart failure; the cart call decides on its own.
    }
    return _repo.fetch();
  }

  Future<void> _reload() async => state = AsyncData(await _repo.fetch());

  Future<void> refresh() => _reload();

  Future<void> add({
    required int productId,
    int? variantId,
    int quantity = 1,
  }) async {
    await _repo.add(
      productId: productId,
      variantId: variantId,
      quantity: quantity,
    );
    await _reload();
  }

  Future<void> setQuantity(int cartItemId, int quantity) async {
    await _repo.setQuantity(cartItemId, quantity);
    await _reload();
  }

  Future<void> remove(int cartItemId) async {
    await _repo.remove(cartItemId);
    await _reload();
  }

  /// The buyer accepts the new prices: PATCH each affected line with its current
  /// quantity, then checkout can be retried.
  Future<void> acceptPriceChanges() async {
    final cart = state.value ?? await _repo.fetch();
    for (final item in cart.priceChangedItems) {
      await _repo.setQuantity(item.id, item.quantity);
    }
    await _reload();
  }
}

final cartProvider = AsyncNotifierProvider<CartController, CartRead>(
  CartController.new,
  retry: retryTransient,
);

/// For the tab badge; 0 while loading or on error.
final cartItemCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).value?.itemCount ?? 0,
);
