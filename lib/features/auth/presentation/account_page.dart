import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../data/auth_repository.dart';
import '../data/user.dart';
import 'auth_widgets.dart';

/// The Profile tab: who is signed in, my orders, language and theme, password, sign out.
/// A guest never sees it: `/account` is a protected path, so the router asks for sign-in.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final t = ref.read(tProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(sessionProvider.notifier).logout();
      router.go(Paths.home);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t('header.signOutFailed'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(sessionProvider).value;
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    if (user == null) {
      // Signed out a moment ago (or the session ended): the router is moving on.
      return const Scaffold(body: LoadingState());
    }

    return Scaffold(
      appBar: AppBar(title: Text(t('account.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('account.profile'), style: text.titleMedium),
                  const SizedBox(height: 12),
                  _Field(
                    t('account.fullName'),
                    user.fullName ?? t('account.notSet'),
                  ),
                  _Field(t('account.email'), user.email),
                  _Field(t('account.phone'), user.phone ?? t('account.notSet')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (_) => _EditProfileSheet(user: user),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(t('account.edit')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(t('account.orders')),
                  subtitle: Text(t('account.ordersHint')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Paths.orders),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(t('account.changePassword')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (_) => const _ChangePasswordSheet(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('header.settings'), style: text.titleMedium),
                  const SizedBox(height: 12),
                  Text(t('locale.label'), style: text.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<AppLocale>(
                    showSelectedIcon: false,
                    segments: [
                      for (final locale in AppLocale.values)
                        ButtonSegment(
                          value: locale,
                          label: Text(locale.nativeName, maxLines: 1),
                        ),
                    ],
                    selected: {settings.locale},
                    onSelectionChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setLocale(value.first),
                  ),
                  const SizedBox(height: 16),
                  Text(t('theme.label'), style: text.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(t('theme.light')),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(t('theme.dark')),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(t('theme.system')),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(value.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.destructive,
            ),
            icon: const Icon(Icons.logout),
            label: Text(t('header.signOut')),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.mutedForeground),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final UserRead user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.user.fullName ?? '');
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  String? _nameKey;
  String? _phoneKey;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = ref.read(tProvider);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final hadPhone = (widget.user.phone ?? '').isNotEmpty;
    setState(() {
      // The API takes 1-255 characters for a name and 5-30 for a phone.
      _nameKey = name.isEmpty && (widget.user.fullName ?? '').isNotEmpty
          ? 'checkout.nameRequired'
          : null;
      _phoneKey = phone.isNotEmpty && (phone.length < 5 || phone.length > 30)
          ? 'checkout.phoneInvalid'
          : null;
      _error = null;
    });
    if (_nameKey != null || _phoneKey != null) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(sessionProvider.notifier)
          .updateProfile(
            fullName: name.isEmpty ? null : name,
            phone: phone.isEmpty ? null : phone,
            // Emptying the field clears the phone; only send that if there was one.
            clearPhone: phone.isEmpty && hadPhone,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(t('account.saved'))));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = apiErrorMessage(error, t('account.saveFailed'));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('account.edit'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_error != null) FormErrorBanner(_error!),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t('account.fullName'),
                errorText: _nameKey == null ? null : t(_nameKey!),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: t('account.phone'),
                errorText: _phoneKey == null ? null : t(_phoneKey!),
              ),
            ),
            const SizedBox(height: 16),
            SubmitButton(
              label: t('account.save'),
              busy: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _currentKey;
  String? _nextKey;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = ref.read(tProvider);
    setState(() {
      _currentKey = passwordRequiredError(_current.text);
      _nextKey = newPasswordError(_next.text);
      _error = null;
    });
    if (_currentKey != null || _nextKey != null) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // The backend signs out the other sessions and keeps this one with a fresh cookie.
      await ref
          .read(sessionProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(t('account.passwordChanged'))),
      );
    } catch (error) {
      if (!mounted) return;
      // A wrong current password is a 400 with a readable message.
      setState(() {
        _busy = false;
        _error = apiErrorMessage(error, t('account.passwordFailed'));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('account.changePassword'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_error != null) FormErrorBanner(_error!),
            PasswordField(
              controller: _current,
              label: t('account.currentPassword'),
              error: _currentKey == null ? null : t(_currentKey!),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _next,
              label: t('auth.newPassword'),
              error: _nextKey == null ? null : t(_nextKey!),
              newPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 16),
            SubmitButton(
              label: t('auth.resetSubmit'),
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
