import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';
import '../../catalog/presentation/product_card.dart';
import '../application/cart_controller.dart';
import '../data/cart.dart';

const _maxQuantity = 99;

/// The cart tab. Works logged out (guest cart); checkout needs a login, which the router
/// asks for. Lines are grouped by shop, since fulfillment and refunds are per shop.
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  /// Lines with a request in flight: their controls are off until it finishes.
  final _busy = <int>{};

  Future<void> _run(int itemId, Future<void> Function() action) async {
    final t = ref.read(tProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(itemId));
    try {
      await action();
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(error, t('cart.updateFailed'))),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy.remove(itemId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final cart = ref.watch(cartProvider);
    final controller = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(t('nav.cart'))),
      body: cart.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: apiErrorMessage(error, t('state.loadFailed')),
          onRetry: () => ref.invalidate(cartProvider),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return EmptyState(
              message: '${t('cart.emptyTitle')}\n${t('cart.emptyBody')}',
              action: FilledButton(
                onPressed: () => context.go(Paths.catalog),
                style: FilledButton.styleFrom(minimumSize: const Size(200, 44)),
                child: Text(t('home.heroCta')),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                for (final group in _groupByShop(data.items)) ...[
                  _ShopHeader(group.first.shop.name, group.first.shop.slug),
                  for (final item in group)
                    _CartLine(
                      item: item,
                      busy: _busy.contains(item.id),
                      onQuantity: (q) => _run(
                        item.id,
                        () => controller.setQuantity(item.id, q),
                      ),
                      onRemove: () =>
                          _run(item.id, () => controller.remove(item.id)),
                      onAcceptPrice: () => _run(
                        item.id,
                        () => controller.setQuantity(item.id, item.quantity),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                _Summary(cart: data),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shops in order of their first line, lines in cart order within each.
List<List<CartItemRead>> _groupByShop(List<CartItemRead> items) {
  final groups = <int, List<CartItemRead>>{};
  for (final item in items) {
    groups.putIfAbsent(item.shop.id, () => []).add(item);
  }
  return groups.values.toList();
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader(this.name, this.slug);

  final String name;
  final String slug;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(Paths.shop(slug)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CartLine extends ConsumerWidget {
  const _CartLine({
    required this.item,
    required this.busy,
    required this.onQuantity,
    required this.onRemove,
    required this.onAcceptPrice,
  });

  final CartItemRead item;
  final bool busy;
  final void Function(int quantity) onQuantity;
  final VoidCallback onRemove;
  final VoidCallback onAcceptPrice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final intl = ref.watch(settingsProvider.select((s) => s.locale.intlTag));
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final variant = item.variant?.attributes.values.join(' / ');
    final short = item.available && !item.inStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: item.available
                      ? () => context.push(
                          Paths.product(item.shop.slug, item.product.slug),
                        )
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: ProductImage(item.product.imageUrl),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                      if (variant != null && variant.isNotEmpty)
                        Text(
                          variant,
                          style: text.bodySmall?.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        t('cart.perItem', {
                          'price': formatMoney(item.unitPrice, intl),
                        }),
                        style: text.bodySmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: t('cart.remove'),
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (!item.available)
              _Notice(t('cart.unavailable'), colors.destructive)
            else ...[
              if (short) _Notice(t('cart.notEnoughStock'), colors.warning),
              if (item.priceChanged)
                _PriceChanged(
                  message: t('cart.priceChanged', {
                    'old': formatMoney(item.priceSnapshot, intl),
                    'price': formatMoney(item.unitPrice, intl),
                  }),
                  action: t('cart.acceptPrice'),
                  onAccept: busy ? null : onAcceptPrice,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: t('product.decrease'),
                    onPressed: busy || item.quantity <= 1
                        ? null
                        : () => onQuantity(item.quantity - 1),
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${item.quantity}',
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: t('product.increase'),
                    onPressed: busy || item.quantity >= _maxQuantity
                        ? null
                        : () => onQuantity(item.quantity + 1),
                    icon: const Icon(Icons.add),
                  ),
                  const Spacer(),
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      formatMoney(item.lineTotal, intl),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, this.color);

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: TextStyle(color: color)),
        ),
      ],
    ),
  );
}

class _PriceChanged extends StatelessWidget {
  const _PriceChanged({
    required this.message,
    required this.action,
    required this.onAccept,
  });

  final String message;
  final String action;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(message, style: TextStyle(color: colors.warning)),
          TextButton(onPressed: onAccept, child: Text(action)),
        ],
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.cart});

  final CartRead cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final intl = ref.watch(settingsProvider.select((s) => s.locale.intlTag));
    final signedIn = ref.watch(sessionProvider.select((s) => s.value != null));
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    final unavailable = cart.hasUnavailableItems;
    final short = cart.items.any((item) => item.available && !item.inStock);
    final blocked = unavailable || short;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('cart.summary'), style: text.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(t('cart.itemCount', {'count': cart.itemCount})),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(t('cart.total'), style: text.titleSmall),
                const Spacer(),
                Text(
                  formatMoney(cart.subtotal, intl),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (unavailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t('cart.removeUnavailable'),
                  style: TextStyle(color: colors.mutedForeground),
                ),
              )
            else if (short)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t('cart.fixStock'),
                  style: TextStyle(color: colors.mutedForeground),
                ),
              ),
            // Checkout needs a login: the router sends a guest to sign in and back.
            FilledButton(
              onPressed: blocked ? null : () => context.push(Paths.checkout),
              child: Text(
                signedIn ? t('cart.checkout') : t('cart.signInToCheckout'),
              ),
            ),
            if (!signedIn)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t('cart.guestNote'),
                  style: text.bodySmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
