import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_pages.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/catalog/presentation/catalog_pages.dart';
import '../../features/checkout/presentation/checkout_page.dart';
import '../../features/orders/presentation/order_detail_page.dart';
import '../../features/orders/presentation/orders_list_page.dart';
import '../../features/catalog/presentation/product_page.dart';
import '../settings/settings.dart';
import '../widgets/main_shell.dart';
import '../widgets/state_views.dart';
import 'paths.dart';

/// Screens not built yet show [ComingSoon] under their final path, so navigation, deep links
/// and the auth redirects can be built and tested first. Replace each `_Soon` with the real
/// screen as it lands.
class _Soon extends ConsumerWidget {
  const _Soon(this.titleKey);

  final String titleKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ComingSoon(title: ref.watch(tProvider)(titleKey));
}

/// Redirect rules (same as the storefront's middleware):
/// - protected screens (`/checkout`, `/orders`, `/account`) need a session, else
///   `/login?next=<where you were going>`;
/// - `/login` and `/register` with a session go to `?next=` (checked with `safeNextPath`)
///   or home;
/// - while the first session check is still running nothing is decided yet.
String? authRedirect(AsyncValue<Object?> session, Uri uri) {
  final path = uri.path;
  if (!session.hasValue && !session.hasError) return null;
  final signedIn = session.value != null;
  if (isProtectedPath(path) && !signedIn) return loginLocation(uri.toString());
  if (isAuthPath(path) && signedIn) {
    return safeNextPath(uri.queryParameters['next']);
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirects when the session changes (login, logout, 401 expiry).
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Paths.home,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(sessionProvider), state.uri),
    errorBuilder: (context, state) => const _NotFound(),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.home,
                builder: (context, state) => const _Soon('nav.home'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.catalog,
                builder: (context, state) => const CatalogPage(),
                routes: [
                  GoRoute(
                    path: ':slug',
                    builder: (context, state) =>
                        CatalogPage(slug: state.pathParameters['slug']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.search,
                builder: (context, state) =>
                    SearchPage(query: state.uri.queryParameters['q'] ?? ''),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.cart,
                builder: (context, state) => const CartPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.account,
                builder: (context, state) => const _Soon('account.title'),
                routes: [
                  GoRoute(path: 'orders', redirect: (_, state) => Paths.orders),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes above the tabs.
      GoRoute(
        path: Paths.orders,
        builder: (context, state) => const OrdersListPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => OrderDetailPage(
              orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              placed: state.uri.queryParameters['placed'] == '1',
            ),
          ),
        ],
      ),
      GoRoute(
        path: Paths.checkout,
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(
        path: Paths.login,
        builder: (context, state) => AuthPage(
          mode: AuthMode.login,
          next: state.uri.queryParameters['next'],
        ),
      ),
      GoRoute(
        path: Paths.register,
        builder: (context, state) => AuthPage(
          mode: AuthMode.register,
          next: state.uri.queryParameters['next'],
        ),
      ),
      GoRoute(
        path: Paths.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/shops/:shop',
        builder: (context, state) => const _Soon('nav.catalog'),
        routes: [
          GoRoute(
            path: ':product',
            builder: (context, state) => ProductPage(
              shopSlug: state.pathParameters['shop']!,
              productSlug: state.pathParameters['product']!,
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _NotFound extends ConsumerWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t('notFound.title'))),
      body: ErrorState(
        message: t('notFound.body'),
        onRetry: () => context.go(Paths.home),
      ),
    );
  }
}
