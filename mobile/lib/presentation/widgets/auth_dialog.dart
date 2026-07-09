import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';

/// What the auth dialog opens on. Both modes live in one dialog with a toggle:
/// creating an account and signing back into one are two sides of the same
/// door, and either can lead into the other mid-flow.
enum AuthIntent { signIn, createAccount }

/// Sign in to an existing account or create a new one (email + password).
/// Returns true when the user ends the flow with a real session.
///
/// Puff is anonymous-first, but anything account-bound — Pro, cloud sync —
/// needs a real sign-in: an anonymous session can't own a subscription or
/// follow you to a new phone. The paywall opens this on [AuthIntent.createAccount]
/// (with a "already have an account?" escape hatch); the You screen opens it on
/// [AuthIntent.signIn] so free users can reclaim their Pro account.
///
/// Reports its own outcome via a snackbar; callers only need the boolean.
Future<bool> showAuthDialog(
  BuildContext context, {
  AuthIntent initial = AuthIntent.signIn,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => _AuthDialog(initial: initial),
      ) ??
      false;
}

/// Owns its text controllers so they're disposed in [State.dispose] — after the
/// dialog's dismiss transition finishes unmounting the fields. Disposing them
/// synchronously after `showDialog` returns instead races that transition and
/// throws "TextEditingController used after being disposed".
class _AuthDialog extends StatefulWidget {
  const _AuthDialog({required this.initial});

  final AuthIntent initial;

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  late AuthIntent _mode = widget.initial;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  bool get _isCreate => _mode == AuthIntent.createAccount;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final strings = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();
    final intent = _mode;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _busy = true);
    final ok = intent == AuthIntent.createAccount
        ? await auth.upgrade(email: email, password: password)
        : await auth.signIn(email: email, password: password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            intent == AuthIntent.createAccount
                ? strings.accountCreated
                : strings.signInSuccess,
          ),
        ),
      );
    } else {
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            intent == AuthIntent.createAccount
                ? strings.accountUpgradeFailed
                : strings.signInFailed,
          ),
        ),
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _isCreate ? AuthIntent.signIn : AuthIntent.createAccount;
      _confirmController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final title =
        _isCreate ? strings.createAccountButton : strings.logInButton;
    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !_busy,
              decoration: InputDecoration(labelText: strings.emailLabel),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : strings.emailInvalid,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              enabled: !_busy,
              autofillHints: [
                _isCreate ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: InputDecoration(labelText: strings.passwordLabel),
              textInputAction:
                  _isCreate ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: _isCreate ? null : (_) => _submit(),
              validator: (v) => _isCreate
                  ? ((v ?? '').length >= 8 ? null : strings.passwordTooShort)
                  : ((v ?? '').isNotEmpty ? null : strings.passwordRequired),
            ),
            if (_isCreate) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                decoration:
                    InputDecoration(labelText: strings.confirmPasswordLabel),
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => v == _passwordController.text
                    ? null
                    : strings.passwordMismatch,
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _toggleMode,
                child: Text(
                  _isCreate
                      ? strings.authHaveAccount
                      : strings.authNeedAccount,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(title),
        ),
      ],
    );
  }
}
