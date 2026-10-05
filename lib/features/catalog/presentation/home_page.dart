import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../application/catalog_providers.dart';
import '../application/product_providers.dart';
import '../data/catalog_repository.dart';
import '../data/product.dart';
import 'product_card.dart';

/// How many of the biggest categories get their own row of new products.
const homeCategoryRails = 3;

/// The Home tab: a search box, a short welcome, categories, new products and how it works.
/// Real data only. A section whose request fails is left out, not shown as an error.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final roots = ref.watch(categoryTreeProvider).value ?? const [];
    final biggest = [...roots]
      ..sort((a, b) => b.productCount.compareTo(a.productCount));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('common.appName'),
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoryTreeProvider);
          ref.invalidate(productRailProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => context.go(Paths.search),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.primary, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: colors.mutedForeground),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('header.searchPlaceholder'),
                          style: TextStyle(color: colors.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: colors.muted,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('home.heroTitle'), style: text.titleLarge),
                      const SizedBox(height: 8),
                      Text(t('home.heroBody')),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go(Paths.catalog),
                        child: Text(t('home.heroCta')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (roots.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(t('home.categoriesTitle'), style: text.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in roots)
                      ActionChip(
                        label: Text(categoryName(category, locale)),
                        onPressed: () =>
                            context.push(Paths.category(category.slug)),
                      ),
                  ],
                ),
              ),
            ],
            ProductRail(
              title: t('home.newArrivals'),
              query: const CatalogQuery(sort: CatalogSort.newest),
              onSeeAll: () => context.go(Paths.catalog),
            ),
            for (final category in biggest.take(homeCategoryRails))
              ProductRail(
                title: categoryName(category, locale),
                query: CatalogQuery(
                  categoryId: category.id,
                  sort: CatalogSort.newest,
                ),
                onSeeAll: () => context.push(Paths.category(category.slug)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(t('home.stepsTitle'), style: text.titleMedium),
            ),
            for (final (icon, title, body) in [
              (
                Icons.shopping_basket_outlined,
                'home.step1Title',
                'home.step1Body',
              ),
              (Icons.place_outlined, 'home.step2Title', 'home.step2Body'),
              (
                Icons.account_balance_wallet_outlined,
                'home.step3Title',
                'home.step3Body',
              ),
            ])
              ListTile(
                leading: Icon(icon, color: colors.primary),
                title: Text(t(title)),
                subtitle: Text(t(body)),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
