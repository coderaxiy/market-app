// Route paths, mirroring the storefront's pages, and the auth redirect rules ported from
// its `src/lib/auth.ts`.

abstract final class Paths {
  static const home = '/';
  static const catalog = '/catalog';
  static const search = '/search';
  static const cart = '/cart';
  static const account = '/account';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const login = '/login';
  static const register = '/register';

  static String category(String slug) =>
      '/catalog/${Uri.encodeComponent(slug)}';

  static String order(int id) => '/orders/$id';

  static String shop(String shopSlug) =>
      '/shops/${Uri.encodeComponent(shopSlug)}';

  static String product(String shopSlug, String productSlug) =>
      '/shops/${Uri.encodeComponent(shopSlug)}/${Uri.encodeComponent(productSlug)}';
}

/// Screens that need a session. Everything else is public. Prefix match. `/cart` is public:
/// guests have a cart too (the backend's `cart_token` cookie).
const protectedPaths = [Paths.checkout, Paths.orders, Paths.account];

bool isProtectedPath(String path) => protectedPaths.any(
  (protected) => path == protected || path.startsWith('$protected/'),
);

bool isAuthPath(String path) => path == Paths.login || path == Paths.register;

/// Only same-app relative paths are allowed as `?next=` targets, so the login screen can't
/// be used as an open redirect (`//evil.com`, `https://...`, `/\evil.com`).
String safeNextPath(String? next, {String fallback = Paths.home}) {
  if (next == null ||
      !next.startsWith('/') ||
      next.startsWith('//') ||
      next.startsWith(r'/\')) {
    return fallback;
  }
  return next;
}

/// `/login?next=/orders/5`, to come back after signing in.
String loginLocation(String next) =>
    '${Paths.login}?next=${Uri.encodeQueryComponent(next)}';
