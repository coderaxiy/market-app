import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../cart/application/cart_controller.dart';
import '../application/product_providers.dart';
import '../application/product_view_logic.dart';
import '../data/catalog_repository.dart';
import '../data/product.dart';
import 'product_card.dart';

const _maxQuantity = 99;

/// `/shops/:shop/:product`: gallery, price, variant picker, add to cart, specs, description
/// and two rails. The chosen variant drives photos, price, stock and article.
class ProductPage extends ConsumerWidget {
  const ProductPage({
    super.key,
    required this.shopSlug,
    required this.productSlug,
  });

  final String shopSlug;
  final String productSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final ref0 = (shop: shopSlug, product: productSlug);
    final product = ref.watch(productProvider(ref0));
    return product.when(
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
                onRetry: () => ref.invalidate(productProvider(ref0)),
              ),
      ),
      data: (data) {
        // A renamed product or shop: the response has the current slugs. Show the
        // canonical route (the storefront redirects).
        if (data.slug != productSlug || data.shop.slug != shopSlug) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.replace(Paths.product(data.shop.slug, data.slug));
            }
          });
        }
        return _ProductView(product: data);
      },
    );
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({required this.product});

  final ProductPublicRead product;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends ConsumerState<_ProductView> {
  final _gallery = PageController();
  late Selection _selection;
  var _quantity = 1;
  var _adding = false;
  List<VariantAxis> _axes = const [];

  ProductPublicRead get _product => widget.product;

  @override
  void initState() {
    super.initState();
    // Axes without labels first (raw keys); the category attributes refine them.
    _axes = buildAxes(_product, const [], ref.read(settingsProvider).locale);
    _selection = initialSelection(_product, _axes);
  }

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  ProductPublicVariantRead? get _variant => _product.hasVariants
      ? findVariant(_product.variants, _selection, _axes)
      : null;

  bool get _inStock =>
      _product.hasVariants ? (_variant?.inStock ?? false) : _product.inStock;

  bool get _canAdd =>
      _inStock && (!_product.hasVariants || _variant != null) && !_adding;

  void _choose(String key, String value) {
    setState(() {
      _selection = choose(_selection, key, value, _product.variants, _axes);
      if (_gallery.hasClients) _gallery.jumpToPage(0);
    });
  }

  Future<void> _addToCart() async {
    final t = ref.read(tProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      await ref
          .read(cartProvider.notifier)
          .add(
            productId: _product.id,
            variantId: _variant?.id,
            quantity: _quantity,
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${t('product.addedToCart')}: ${_product.title}'),
            action: SnackBarAction(
              label: t('nav.cart'),
              onPressed: () => context.go(Paths.cart),
            ),
          ),
        );
    } catch (error) {
      // Stock and availability messages are strings from the backend: safe to show.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(error, t('product.addFailed'))),
          ),
        );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    // Refine the picker with the category's labels and order once they arrive.
    if (_product.hasVariants) {
      final attributes = ref.watch(
        categoryAttributesProvider(_product.category.id),
      );
      final loaded = attributes.value;
      if (loaded != null) {
        final refined = buildAxes(_product, loaded, locale);
        if (refined.length == _axes.length) _axes = refined;
      }
    }

    final variant = _variant;
    final price = variant?.price ?? _product.priceMin;
    final priceText = _product.hasVariants && variant == null
        ? priceLabel(_product.priceMin, _product.priceMax, locale.intlTag, t)
        : formatMoney(price, locale.intlTag);
    final sku = variant?.platformSku ?? _product.platformSku;
    final images = orderedImages(_product, variant);
    final specs = specRows(_product, locale, t);

    return Scaffold(
      appBar: AppBar(title: Text(_product.shop.name)),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  priceText,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: FilledButton.icon(
                  onPressed: _canAdd ? _addToCart : null,
                  icon: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                    _inStock ? t('product.addToCart') : t('catalog.outOfStock'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        children: [
          _Gallery(images: images, controller: _gallery, title: _product.title),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_product.brand != null)
                  Text(
                    _product.brand!.name,
                    style: text.labelLarge?.copyWith(color: colors.accent),
                  ),
                Text(_product.title, style: text.titleLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      priceText,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text(
                        _inStock
                            ? t('product.inStock')
                            : t('catalog.outOfStock'),
                      ),
                      backgroundColor: _inStock
                          ? colors.success.withValues(alpha: 0.15)
                          : colors.secondary,
                    ),
                  ],
                ),
                if (sku != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${t('product.article')}: $sku',
                      style: text.bodySmall?.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                for (final axis in _axes)
                  _AxisPicker(
                    axis: axis,
                    selected: _selection[axis.key],
                    stateOf: (value) => optionState(
                      axis.key,
                      value,
                      _selection,
                      _product.variants,
                      _axes,
                    ),
                    onChoose: (value) => _choose(axis.key, value),
                  ),
                const SizedBox(height: 16),
                _QuantityStepper(
                  quantity: _quantity,
                  onChanged: (value) => setState(() => _quantity = value),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text('${t('product.soldBy')} ${_product.shop.name}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Paths.shop(_product.shop.slug)),
                ),
                _InfoTile(
                  icon: Icons.place_outlined,
                  title: t('product.pickupTitle'),
                  body: t('product.pickupBody'),
                ),
                _InfoTile(
                  icon: Icons.search,
                  title: t('product.inspectTitle'),
                  body: t('product.inspectBody'),
                ),
                if (_product.description != null &&
                    _product.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(t('product.description'), style: text.titleMedium),
                  const SizedBox(height: 8),
                  Text(_product.description!),
                ],
                if (specs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(t('product.specs'), style: text.titleMedium),
                  const SizedBox(height: 8),
                  for (final row in specs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              row.label,
                              style: TextStyle(color: colors.mutedForeground),
                            ),
                          ),
                          Expanded(child: Text(row.value)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          _Rail(
            title: t('product.similar'),
            query: CatalogQuery(categoryId: _product.category.id),
            exclude: {_product.id},
          ),
          _Rail(
            title: t('product.moreFromShop', {'shop': _product.shop.name}),
            query: CatalogQuery(shopId: _product.shop.id),
            exclude: {_product.id},
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Gallery extends ConsumerStatefulWidget {
  const _Gallery({
    required this.images,
    required this.controller,
    required this.title,
  });

  final List<ProductPublicImageRead> images;
  final PageController controller;
  final String title;

  @override
  ConsumerState<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends ConsumerState<_Gallery> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = ref.watch(tProvider);
    final images = widget.images;
    if (images.isEmpty) {
      return AspectRatio(aspectRatio: 1, child: ProductImage(null));
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              PageView.builder(
                controller: widget.controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Semantics(
                  label: widget.title,
                  child: ProductImage(images[i].url, fit: BoxFit.contain),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.card.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        child: Text('${_index + 1} / ${images.length}'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 64,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Semantics(
                button: true,
                label: t('product.showPhoto', {'index': i + 1}),
                child: GestureDetector(
                  onTap: () => widget.controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: i == _index ? colors.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ProductImage(images[i].url),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AxisPicker extends StatelessWidget {
  const _AxisPicker({
    required this.axis,
    required this.selected,
    required this.stateOf,
    required this.onChoose,
  });

  final VariantAxis axis;
  final String? selected;
  final OptionState Function(String value) stateOf;
  final void Function(String value) onChoose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(axis.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in axis.options)
                ChoiceChip(
                  label: Text(value),
                  selected: selected == value,
                  onSelected: (_) => onChoose(value),
                  // Sold out here, or only with a different choice elsewhere: still
                  // selectable (it jumps to a matching variant), but quieter.
                  labelStyle: stateOf(value) == OptionState.available
                      ? null
                      : TextStyle(
                          color: colors.mutedForeground,
                          decoration: stateOf(value) == OptionState.soldOut
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final void Function(int value) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return Row(
      children: [
        Text(
          t('product.quantity'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const Spacer(),
        IconButton.outlined(
          tooltip: t('product.decrease'),
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.outlined(
          tooltip: t('product.increase'),
          onPressed: quantity < _maxQuantity
              ? () => onChanged(quantity + 1)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(body),
  );
}

/// A horizontal row of cards. Hidden while loading, on failure, and when it would be
/// empty after leaving out the product itself.
class _Rail extends ConsumerWidget {
  const _Rail({
    required this.title,
    required this.query,
    required this.exclude,
  });

  final String title;
  final CatalogQuery query;
  final Set<int> exclude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(productRailProvider(query)).value;
    final shown = [
      for (final item in items ?? const <ProductCardRead>[])
        if (!exclude.contains(item.id)) item,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 300,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                SizedBox(width: 170, child: ProductCard(shown[i])),
          ),
        ),
      ],
    );
  }
}
