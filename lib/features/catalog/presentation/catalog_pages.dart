import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/widgets/state_views.dart';
import '../application/catalog_providers.dart';
import '../data/catalog_repository.dart';
import '../data/category.dart';
import 'product_list.dart';

/// `/catalog` (every product, root categories on top) and `/catalog/:slug` (one category
/// with its subcategories). Slugs are globally unique, so the cached tree resolves them.
class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key, this.slug});

  final String? slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    final tree = ref.watch(categoryTreeProvider);

    return tree.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(t('nav.catalog'))),
        body: const LoadingState(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(t('nav.catalog'))),
        body: ErrorState(
          message: apiErrorMessage(error, t('state.loadFailed')),
          onRetry: () => ref.invalidate(categoryTreeProvider),
        ),
      ),
      data: (roots) {
        final category = slug == null ? null : findCategoryBySlug(roots, slug!);
        if (slug != null && category == null) {
          return Scaffold(
            appBar: AppBar(title: Text(t('notFound.title'))),
            body: ErrorState(
              message: t('notFound.body'),
              onRetry: () => context.go(Paths.catalog),
            ),
          );
        }
        final children = category == null ? roots : category.children;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              category == null
                  ? t('nav.catalog')
                  : categoryName(category, locale),
            ),
          ),
          body: ProductListView(
            // A new category is a new query, so the list restarts at page one.
            key: ValueKey(category?.id),
            base: CatalogQuery(categoryId: category?.id),
            header: [
              if (children.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CategoryChips(
                    title: t(
                      category == null
                          ? 'catalog.categories'
                          : 'catalog.subcategories',
                    ),
                    categories: children,
                    locale: locale,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.title,
    required this.categories,
    required this.locale,
  });

  final String title;
  final List<CategoryNodeRead> categories;
  final AppLocale locale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                ActionChip(
                  label: Text(
                    '${categoryName(category, locale)} · ${category.productCount}',
                  ),
                  onPressed: () => context.push(Paths.category(category.slug)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `/search?q=`: the search box on top, results below. An empty query shows a prompt.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.query = ''});

  final String query;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final _controller = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(SearchPage old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query && _controller.text != widget.query) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    context.go(
      q.isEmpty
          ? Paths.search
          : '${Paths.search}?q=${Uri.encodeQueryComponent(q)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final q = widget.query.trim();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: q.isEmpty,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: t('header.searchPlaceholder'),
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
        ),
      ),
      body: q.isEmpty
          ? EmptyState(
              message:
                  '${t('catalog.searchPromptTitle')}\n${t('catalog.searchPromptBody')}',
            )
          : ProductListView(
              key: ValueKey(q),
              base: CatalogQuery(q: q),
              allowRelevanceSort: true,
              header: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      t('catalog.searchResultsFor', {'query': q}),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
