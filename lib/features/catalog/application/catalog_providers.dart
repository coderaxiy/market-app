import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/i18n/i18n.dart';
import '../data/catalog_repository.dart';
import '../data/category.dart';
import '../data/product.dart';

/// Products per request. The API allows up to 100.
const productPageSize = 20;

/// The public category tree, without branches that have no visible products (the
/// storefront's `nonEmptyCategories`). The server caches it for 5 minutes.
final categoryTreeProvider = FutureProvider<List<CategoryNodeRead>>(
  (ref) async => nonEmptyCategories(
    await ref.watch(catalogRepositoryProvider).categories(),
  ),
  retry: retryTransient,
);

List<CategoryNodeRead> nonEmptyCategories(List<CategoryNodeRead> nodes) => [
  for (final node in nodes)
    if (node.productCount > 0)
      CategoryNodeRead(
        id: node.id,
        parentId: node.parentId,
        slug: node.slug,
        iconUrl: node.iconUrl,
        sortOrder: node.sortOrder,
        isLeaf: node.isLeaf,
        translations: node.translations,
        productCount: node.productCount,
        children: nonEmptyCategories(node.children),
      ),
];

/// A category by its (globally unique) slug, searching the whole tree.
CategoryNodeRead? findCategoryBySlug(List<CategoryNodeRead> tree, String slug) {
  for (final node in tree) {
    if (node.slug == slug) return node;
    final found = findCategoryBySlug(node.children, slug);
    if (found != null) return found;
  }
  return null;
}

/// The category's name in the buyer's language (current -> en -> first), else its slug.
String categoryName(CategoryNodeRead node, AppLocale locale) =>
    pickTranslation(node.translations, (t) => t.locale, locale)?.name ??
    node.slug;

class ProductListState {
  const ProductListState({
    required this.items,
    this.total,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<ProductCardRead> items;

  /// From `X-Total-Count`; null if the server didn't send it.
  final int? total;
  final bool hasMore;
  final bool loadingMore;

  /// The last "load more" failed: show a retry, keep the items.
  final bool loadMoreFailed;

  ProductListState copyWith({
    List<ProductCardRead>? items,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => ProductListState(
    items: items ?? this.items,
    total: total,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

/// One query's products, loaded a page at a time for infinite scroll. A new query is a new
/// family member, so changing the sort or a filter starts again from the first page.
class ProductListController extends AsyncNotifier<ProductListState> {
  ProductListController(this.query);

  final CatalogQuery query;

  @override
  Future<ProductListState> build() async {
    final page = await ref
        .read(catalogRepositoryProvider)
        .products(query, limit: productPageSize);
    return ProductListState(
      items: page.items,
      total: page.total,
      hasMore: _hasMore(page, page.items.length),
    );
  }

  /// With the total header: more while we have fewer than it. Without: more while pages
  /// come back full.
  bool _hasMore(Page<ProductCardRead> page, int loaded) => page.total != null
      ? loaded < page.total!
      : page.items.length == productPageSize;

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await ref
          .read(catalogRepositoryProvider)
          .products(query, skip: current.items.length, limit: productPageSize);
      final items = [...current.items, ...page.items];
      state = AsyncData(
        ProductListState(
          items: items,
          total: page.total ?? current.total,
          hasMore: page.items.isNotEmpty && _hasMore(page, items.length),
        ),
      );
    } catch (_) {
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

final productListProvider =
    AsyncNotifierProvider.family<
      ProductListController,
      ProductListState,
      CatalogQuery
    >(ProductListController.new, retry: retryTransient);
