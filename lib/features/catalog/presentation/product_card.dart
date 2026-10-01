import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../data/product.dart';

/// A product photo, or a quiet placeholder when there is none or it fails to load.
class ProductImage extends StatelessWidget {
  const ProductImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final placeholder = ColoredBox(
      color: colors.muted,
      child: Center(
        child: Icon(Icons.image_outlined, color: colors.mutedForeground),
      ),
    );
    final src = url;
    if (src == null) return placeholder;
    return Image.network(
      src,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
      frameBuilder: (context, child, frame, sync) =>
          sync || frame != null ? child : placeholder,
    );
  }
}

/// Price line for a card or product page: one price, or "from {min}" for a range.
String priceLabel(
  String priceMin,
  String priceMax,
  String intlTag,
  String Function(String key, [Map<String, Object>? params]) t,
) {
  final min = formatMoney(priceMin, intlTag);
  return toTiyin(priceMin) == toTiyin(priceMax)
      ? min
      : t('catalog.priceFrom', {'price': min});
}

class ProductCard extends ConsumerWidget {
  const ProductCard(this.product, {super.key});

  final ProductCardRead product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final t = ref.watch(tProvider);
    final intl = ref.watch(settingsProvider.select((s) => s.locale.intlTag));
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(Paths.product(product.shop.slug, product.slug)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The photo takes whatever height the grid cell leaves after the text, so a
            // bigger font scale shrinks the photo instead of overflowing the card.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(product.imageUrl),
                  if (!product.inStock)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            t('catalog.outOfStock'),
                            style: text.labelSmall?.copyWith(
                              color: colors.secondaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceLabel(product.priceMin, product.priceMax, intl, t),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
