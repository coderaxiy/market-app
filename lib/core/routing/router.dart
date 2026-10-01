import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
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
                builder: (context, state) => const _Soon('nav.catalog'),
                routes: [
                  GoRoute(
                    path: ':slug',
                    builder: (context, state) => const _Soon('nav.catalog'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.search,
                builder: (context, state) => const _Soon('nav.search'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Paths.cart,
                builder: (context, state) => const _Soon('nav.cart'),
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
        builder: (context, state) => const _Soon('nav.orders'),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => const _Soon('nav.orders'),
          ),
        ],
      ),
      GoRoute(
        path: Paths.checkout,
        builder: (context, state) => const _Soon('checkout.title'),
      ),
      GoRoute(
        path: Paths.login,
        builder: (context, state) => const _Soon('auth.loginTitle'),
      ),
      GoRoute(
        path: Paths.register,
        builder: (context, state) => const _Soon('auth.registerTitle'),
      ),
      GoRoute(
        path: '/shops/:shop',
        builder: (context, state) => const _Soon('nav.catalog'),
        routes: [
          GoRoute(
            path: ':product',
            builder: (context, state) => const _Soon('nav.catalog'),
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
