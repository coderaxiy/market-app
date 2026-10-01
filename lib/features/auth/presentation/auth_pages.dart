import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../data/auth_repository.dart';
import 'auth_widgets.dart';

enum AuthMode { login, register }

/// Sign in or create an account. On success the session changes and the router redirects
/// to `?next=` (see `authRedirect`), so this page never navigates itself on success.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, required this.mode, this.next});

  final AuthMode mode;

  /// The `?next=` target, kept when switching between sign in and register.
  final String? next;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailKey;
  String? _passwordKey;
  String? _serverError;
  var _busy = false;

  bool get _isLogin => widget.mode == AuthMode.login;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = ref.read(tProvider);
    setState(() {
      _emailKey = emailError(_email.text);
      _passwordKey = passwordRequiredError(_password.text);
      _serverError = null;
    });
    if (_emailKey != null || _passwordKey != null) return;

    setState(() => _busy = true);
    final session = ref.read(sessionProvider.notifier);
    final email = _email.text.trim();
    try {
      if (_isLogin) {
        await session.login(email: email, password: _password.text);
      } else {
        await session.register(
          email: email,
          password: _password.text,
          fullName: _name.text,
        );
      }
    } on SignInAfterRegisterException {
      // The account exists; only the automatic sign-in failed.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = t('auth.registeredSignInFailed');
      });
      context.go(_withNext(Paths.login));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = apiErrorMessage(
          error,
          t(_isLogin ? 'auth.loginFailed' : 'auth.registerFailed'),
        );
      });
    }
    // Success: the router moves on. Nothing to do here (and the page may be gone).
  }

  String _withNext(String path) => widget.next == null
      ? path
      : '$path?next=${Uri.encodeQueryComponent(widget.next!)}';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return AuthScaffold(
      showBack: false,
      title: t(_isLogin ? 'auth.loginTitle' : 'auth.registerTitle'),
      subtitle: t(_isLogin ? 'auth.loginSubtitle' : 'auth.registerSubtitle'),
      children: [
        if (_serverError != null) FormErrorBanner(_serverError!),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isLogin) ...[
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: t('auth.fullName')),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: t('auth.email'),
                  errorText: _emailKey == null ? null : t(_emailKey!),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: t('auth.password'),
                error: _passwordKey == null ? null : t(_passwordKey!),
                newPassword: !_isLogin,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
        if (_isLogin)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => context.push(Paths.forgotPassword),
              child: Text(t('auth.forgotPassword')),
            ),
          ),
        const SizedBox(height: 8),
        SubmitButton(
          label: t(_isLogin ? 'auth.submitLogin' : 'auth.submitRegister'),
          busy: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(t(_isLogin ? 'auth.noAccount' : 'auth.haveAccount')),
            TextButton(
              onPressed: () => context.go(
                _withNext(_isLogin ? Paths.register : Paths.login),
              ),
              child: Text(t(_isLogin ? 'auth.goRegister' : 'auth.goLogin')),
            ),
          ],
        ),
      ],
    );
  }
}

/// Forgotten password: email, then the emailed 6-digit code with a new password. Success
/// signs out every session of the user and does not log in, so it ends on the login screen.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _emailKey;
  String? _codeKey;
  String? _passwordKey;
  String? _serverError;
  var _codeSent = false;
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final t = ref.read(tProvider);
    setState(() {
      _emailKey = emailError(_email.text);
      _serverError = null;
    });
    if (_emailKey != null) return;
    setState(() => _busy = true);
    try {
      // Always succeeds the same way, whether or not the account exists.
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeSent = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = apiErrorMessage(error, t('auth.requestFailed'));
      });
    }
  }

  Future<void> _confirm() async {
    final t = ref.read(tProvider);
    setState(() {
      _codeKey = resetCodeError(_code.text);
      _passwordKey = newPasswordError(_password.text);
      _serverError = null;
    });
    if (_codeKey != null || _passwordKey != null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            email: _email.text.trim(),
            code: _code.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('auth.resetDone'))));
      context.go(Paths.login);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // "Invalid or expired code" is a string detail, safe to show as it is.
        _serverError = apiErrorMessage(error, t('auth.resetFailed'));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = t('auth.resetFailed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    if (!_codeSent) {
      return AuthScaffold(
        title: t('auth.resetTitle'),
        subtitle: t('auth.resetSubtitle'),
        children: [
          if (_serverError != null) FormErrorBanner(_serverError!),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendCode(),
            decoration: InputDecoration(
              labelText: t('auth.email'),
              errorText: _emailKey == null ? null : t(_emailKey!),
            ),
          ),
          const SizedBox(height: 16),
          SubmitButton(
            label: t('auth.sendCode'),
            busy: _busy,
            onPressed: _sendCode,
          ),
        ],
      );
    }
    return AuthScaffold(
      title: t('auth.resetCodeTitle'),
      subtitle: t('auth.resetCodeSubtitle', {'email': _email.text.trim()}),
      children: [
        if (_serverError != null) FormErrorBanner(_serverError!),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: InputDecoration(
            labelText: t('auth.code'),
            counterText: '',
            errorText: _codeKey == null ? null : t(_codeKey!),
          ),
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _password,
          label: t('auth.newPassword'),
          error: _passwordKey == null ? null : t(_passwordKey!),
          newPassword: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _confirm,
        ),
        const SizedBox(height: 16),
        SubmitButton(
          label: t('auth.resetSubmit'),
          busy: _busy,
          onPressed: _confirm,
        ),
        TextButton(
          // 5 wrong guesses kill a code: asking again replaces it.
          onPressed: _busy ? null : () => setState(() => _codeSent = false),
          child: Text(t('auth.sendAgain')),
        ),
        TextButton(
          onPressed: () => context.go(Paths.login),
          child: Text(t('auth.backToLogin')),
        ),
      ],
    );
  }
}
