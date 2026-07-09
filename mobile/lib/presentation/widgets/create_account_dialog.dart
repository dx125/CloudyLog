import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';

/// Collects email + password (with a confirmation field) and attaches them to
/// the current anonymous account. Returns true when the account was created.
///
/// Puff is anonymous-first, but anything account-bound — Pro, cloud sync —
/// needs a real sign-in: an anonymous session can't carry a subscription
/// across devices or reinstalls. The paywall and the You screen both gate on
/// this, so it lives here rather than in either one.
///
/// Reports its own outcome via a snackbar (linked / failed); callers only need
/// the boolean to decide whether to continue.
Future<bool> showCreateAccountDialog(BuildContext context) async {
  final strings = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final auth = context.read<AuthService>();

  final credentials = await showDialog<_Credentials>(
    context: context,
    builder: (_) => const _CreateAccountDialog(),
  );
  if (credentials == null) return false;

  final created = await auth.upgrade(
    email: credentials.email,
    password: credentials.password,
  );
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        created ? strings.accountCreated : strings.accountUpgradeFailed,
      ),
    ),
  );
  return created;
}

typedef _Credentials = ({String email, String password});

/// Owns its text controllers so they're disposed in [State.dispose] — after the
/// dialog's dismiss transition finishes unmounting the fields. Disposing them
/// synchronously after `showDialog` returns instead races that transition and
/// throws "TextEditingController used after being disposed".
class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog();

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(
        (
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.createAccountButton),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: strings.emailLabel),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : strings.emailInvalid,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: strings.passwordLabel),
              validator: (v) =>
                  (v ?? '').length >= 8 ? null : strings.passwordTooShort,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration:
                  InputDecoration(labelText: strings.confirmPasswordLabel),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => v == _passwordController.text
                  ? null
                  : strings.passwordMismatch,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(strings.createAccountButton),
        ),
      ],
    );
  }
}
