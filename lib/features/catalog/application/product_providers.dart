import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../data/catalog_repository.dart';
import '../data/category.dart';
import '../data/product.dart';

/// The shop slug and product slug of `/shops/:shop/:product`.
typedef ProductRef = ({String shop, String product});

/// A product by its slugs. Old slugs keep resolving, so the response carries the current
/// ones: compare them with the route and replace it (the storefront answers with a 301).
final productProvider = FutureProvider.family<ProductPublicRead, ProductRef>(
  (ref, id) =>
      ref.watch(catalogRepositoryProvider).productBySlug(id.shop, id.product),
  retry: retryTransient,
);

/// The category's attribute definitions: labels and order for the variant picker. Only
/// worth fetching for variant products; a failure just leaves raw keys.
final categoryAttributesProvider =
    FutureProvider.family<List<CategoryAttributePublicRead>, int>(
      (ref, categoryId) =>
          ref.watch(catalogRepositoryProvider).categoryAttributes(categoryId),
      retry: retryTransient,
    );

/// A short horizontal rail of cards ("similar products", "more from the shop", home).
final productRailProvider =
    FutureProvider.family<List<ProductCardRead>, CatalogQuery>(
      (ref, query) async =>
          (await ref
                  .watch(catalogRepositoryProvider)
                  .products(query, limit: 12))
              .items,
      retry: retryTransient,
    );
