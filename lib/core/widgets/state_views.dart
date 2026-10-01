import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import '../theme/app_colors.dart';

/// Loading, empty and error states shared by every screen (the storefront's
/// `LoadingState` / `EmptyState` / `ErrorState`).
class LoadingState extends ConsumerWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return Center(
      child: Semantics(
        label: t('common.loading'),
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.mutedForeground),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Defaults to "Nothing here yet."
class EmptyState extends ConsumerWidget {
  const EmptyState({super.key, this.message, this.action});

  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Message(
    icon: Icons.inbox_outlined,
    text: message ?? ref.watch(tProvider)('state.empty'),
    action: action,
  );
}

/// Defaults to "Couldn't load this. Check your connection and try again." Pass
/// `apiErrorMessage(error, ...)` as [message] for a backend message worth showing.
class ErrorState extends ConsumerWidget {
  const ErrorState({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return _Message(
      icon: Icons.error_outline,
      text: message ?? t('state.loadFailed'),
      action: onRetry == null
          ? null
          : OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(120, 44)),
              child: Text(t('common.retry')),
            ),
    );
  }
}

/// A screen that isn't built yet.
class ComingSoon extends ConsumerWidget {
  const ComingSoon({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _Message(
        icon: Icons.hourglass_empty,
        text: '${t('common.comingSoon')}\n${t('placeholder.body')}',
      ),
    );
  }
}
