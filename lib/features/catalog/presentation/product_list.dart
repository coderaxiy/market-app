import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/settings/settings.dart';
import '../../../core/widgets/state_views.dart';
import '../application/catalog_providers.dart';
import '../data/catalog_repository.dart';
import '../data/product.dart';
import 'product_card.dart';

/// Products for a query: a result count, sort and "in stock only" controls, a two-column
/// grid that loads the next page near the bottom, and pull to refresh. [header] slivers
/// (category chips, a results title) go above the controls.
class ProductListView extends ConsumerStatefulWidget {
  const ProductListView({
    super.key,
    required this.base,
    this.header = const [],
    this.allowRelevanceSort = false,
  });

  /// The route-level filters (category, search text). Sort and stock are added here.
  final CatalogQuery base;
  final List<Widget> header;

  /// "Best match" only means something with a search text.
  final bool allowRelevanceSort;

  @override
  ConsumerState<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends ConsumerState<ProductListView> {
  final _scroll = ScrollController();
  CatalogSort? _sort;
  var _inStockOnly = false;

  CatalogQuery get _query =>
      widget.base.copyWith(sort: _sort, inStock: _inStockOnly ? true : null);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.extentAfter < 600) {
      ref.read(productListProvider(_query).notifier).loadMore();
    }
  }

  String _sortLabel(String Function(String) t, CatalogSort sort) =>
      switch (sort) {
        CatalogSort.relevance => t('catalog.sortRelevance'),
        CatalogSort.newest => t('catalog.sortNewest'),
        CatalogSort.priceAsc => t('catalog.sortPriceAsc'),
        CatalogSort.priceDesc => t('catalog.sortPriceDesc'),
      };

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final query = _query;
    final list = ref.watch(productListProvider(query));
    final sorts = [
      if (widget.allowRelevanceSort) CatalogSort.relevance,
      CatalogSort.newest,
      CatalogSort.priceAsc,
      CatalogSort.priceDesc,
    ];
    final effectiveSort =
        _sort ??
        (widget.allowRelevanceSort
            ? CatalogSort.relevance
            : CatalogSort.newest);

    final controls = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (list.value?.total != null)
              Text(t('catalog.productCount', {'count': list.value!.total!})),
            PopupMenuButton<CatalogSort>(
              tooltip: t('catalog.sort'),
              initialValue: effectiveSort,
              onSelected: (sort) => setState(() => _sort = sort),
              itemBuilder: (_) => [
                for (final sort in sorts)
                  PopupMenuItem(value: sort, child: Text(_sortLabel(t, sort))),
              ],
              child: Chip(
                avatar: const Icon(Icons.swap_vert, size: 18),
                label: Text(_sortLabel(t, effectiveSort)),
              ),
            ),
            FilterChip(
              label: Text(t('catalog.inStockOnly')),
              selected: _inStockOnly,
              onSelected: (value) => setState(() => _inStockOnly = value),
            ),
          ],
        ),
      ),
    );

    final Widget body = list.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: LoadingState(),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(
          message: apiErrorMessage(error, t('state.loadFailed')),
          onRetry: () => ref.invalidate(productListProvider(query)),
        ),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              message: _inStockOnly
                  ? t('catalog.filteredEmptyBody')
                  : (widget.base.q?.isNotEmpty ?? false)
                  ? t('catalog.noResultsBody')
                  : t('catalog.emptyBody'),
              action: _inStockOnly
                  ? OutlinedButton(
                      onPressed: () => setState(() => _inStockOnly = false),
                      child: Text(t('catalog.resetFilters')),
                    )
                  : null,
            ),
          );
        }
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 300,
                ),
                itemCount: state.items.length,
                itemBuilder: (_, index) => ProductCard(state.items[index]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: state.loadingMore
                    ? const LoadingState()
                    : state.loadMoreFailed
                    ? ErrorState(
                        onRetry: () => ref
                            .read(productListProvider(query).notifier)
                            .loadMore(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(productListProvider(query).future),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [...widget.header, controls, body],
      ),
    );
  }
}
