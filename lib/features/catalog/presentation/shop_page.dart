import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../application/product_providers.dart';
import '../data/catalog_repository.dart';
import '../data/common.dart';
import 'product_list.dart';
import 'product_card.dart';

/// `/shops/:shop`: the shop's banner, logo, name, rating and description, then its products
/// (the same list as the catalog: sort, in-stock filter, infinite scroll).
class ShopPage extends ConsumerWidget {
  const ShopPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final shop = ref.watch(shopProvider(slug));
    return shop.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: isNotFound(error)
            ? ErrorState(
                message: t('notFound.body'),
                onRetry: () => context.go(Paths.home),
              )
            : ErrorState(
                message: apiErrorMessage(error, t('state.loadFailed')),
                onRetry: () => ref.invalidate(shopProvider(slug)),
              ),
      ),
      data: (data) => Scaffold(
        appBar: AppBar(title: Text(data.name)),
        body: ProductListView(
          base: CatalogQuery(shopId: data.id),
          header: [SliverToBoxAdapter(child: _ShopHeader(shop: data))],
        ),
      ),
    );
  }
}

class _ShopHeader extends ConsumerWidget {
  const _ShopHeader({required this.shop});

  final ShopPublicRead shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final subtle = text.bodySmall?.copyWith(color: colors.mutedForeground);
    final rating = shop.ratingAvg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shop.bannerUrl != null)
          AspectRatio(aspectRatio: 3, child: ProductImage(shop.bannerUrl)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ProductImage(shop.logoUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: text.titleLarge),
                    // Only real data: no rating line for a shop nobody has rated.
                    if (rating != null && shop.ratingCount > 0)
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: colors.warning),
                          const SizedBox(width: 4),
                          Text(
                            '$rating · ${t('shop.ratingCount', {'count': shop.ratingCount})}',
                            style: subtle,
                          ),
                        ],
                      ),
                    Text(
                      t('shop.since', {'date': formatDate(shop.createdAt)}),
                      style: subtle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (shop.description != null && shop.description!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(shop.description!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(t('shop.products'), style: text.titleMedium),
        ),
      ],
    );
  }
}
