import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

/// The app's one `Dio`. Overridden in `main()` with [createDefaultApiClient]; tests
/// override it with a fake adapter.
final dioProvider = Provider<Dio>(
  (ref) => throw UnimplementedError('dioProvider not overridden'),
);

/// The real client: cookies (`access_token`, `cart_token`) persist in app-private storage.
Future<Dio> createDefaultApiClient({void Function()? onUnauthorized}) async {
  final support = await getApplicationSupportDirectory();
  final cookieDir = Directory('${support.path}/cookies')
    ..createSync(recursive: true);
  return createApiClient(cookieDir: cookieDir, onUnauthorized: onUnauthorized);
}
