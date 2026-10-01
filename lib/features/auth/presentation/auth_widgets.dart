import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';

// Validators return a translation key, or null when the value is fine. They run on submit.

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? emailError(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'auth.emailRequired';
  if (!_emailPattern.hasMatch(email)) return 'auth.emailInvalid';
  return null;
}

/// Sign-in only needs *a* password; the backend decides if it is right.
String? passwordRequiredError(String value) =>
    value.isEmpty ? 'auth.passwordRequired' : null;

/// A new password (reset, change): 8 to 72 bytes, the backend's rule.
String? newPasswordError(String value) =>
    isValidNewPassword(value) ? null : 'auth.passwordTooShort';

/// The emailed code is exactly 6 digits.
String? resetCodeError(String value) =>
    RegExp(r'^\d{6}$').hasMatch(value.trim()) ? null : 'auth.codeInvalid';

/// Page frame for the auth screens: scrollable (the keyboard covers half the screen),
/// narrow column, title and subtitle like the storefront's `AuthPage`.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: text.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: text.bodyMedium?.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A password field with the show/hide toggle.
class PasswordField extends ConsumerStatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.error,
    this.newPassword = false,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? error;

  /// `new-password` autofill (register, reset) instead of `current-password` (sign in).
  final bool newPassword;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  ConsumerState<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends ConsumerState<PasswordField> {
  var _visible = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted == null
          ? null
          : (_) => widget.onSubmitted!(),
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.error,
        suffixIcon: IconButton(
          tooltip: _visible ? t('auth.hidePassword') : t('auth.showPassword'),
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

/// The destructive banner above a form for a server error.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.destructive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: colors.destructive)),
          ),
        ],
      ),
    );
  }
}

/// The form's submit button, with a spinner while [busy] (the storefront's auth forms use
/// the default `primary` button too).
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
