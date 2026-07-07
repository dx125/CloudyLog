import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/config_service.dart';
import '../../services/login_service.dart';

/// Sign-in / sign-up screen. Free users never see it — it's pushed from the
/// Pro flow (and pops `true` on success).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  /// Country default comes from the device's region; editable in Settings.
  String? _deviceCountry() {
    final code =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (code == null) return null;
    final upper = code.toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(upper) ? upper : null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final login = context.read<LoginService>();
    final LoginResult result;
    if (_isSignUp) {
      result = await login.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text,
        country: _deviceCountry(),
      );
    } else {
      result = await login.signInWithCredentials(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
    if (!mounted) return;

    if (!result.success) {
      _showError(_errorText(result.error));
      return;
    }
    await _applyDefaultDisplayName(result.user!.displayName);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _signInWithGoogle() async {
    final login = context.read<LoginService>();
    final result = await login.signInWithGoogle();
    if (!mounted) return;

    if (!result.success) {
      _showError(_errorText(result.error));
      return;
    }
    await _applyDefaultDisplayName(result.user!.displayName);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String _errorText(LoginError? error) {
    final strings = AppLocalizations.of(context)!;
    switch (error) {
      case LoginError.invalidCredentials:
        return strings.errorInvalidCredentials;
      case LoginError.emailAlreadyRegistered:
        return strings.errorEmailAlreadyRegistered;
      case LoginError.network:
        return strings.errorNetwork;
      case LoginError.googleUnavailable:
        return strings.googleSignInUnavailable;
      case LoginError.unknown:
      case null:
        return strings.loginFailed;
    }
  }

  Future<void> _applyDefaultDisplayName(String name) async {
    final config = context.read<ConfigService>();
    if (config.displayName.isEmpty) {
      await config.setDisplayName(name);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final login = context.watch<LoginService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? strings.signUpTitle : strings.loginTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.cloud,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.loginWelcome,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _displayNameController,
                        enabled: !login.isInProgress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: strings.displayNameSetting,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return strings.displayNameRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      enabled: !login.isInProgress,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: strings.emailLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty || !trimmed.contains('@')) {
                          return strings.emailRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !login.isInProgress,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: strings.passwordLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return strings.passwordRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: login.isInProgress ? null : _submit,
                      child: login.isInProgress
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isSignUp
                                  ? strings.createAccountButton
                                  : strings.signInButton,
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: login.isInProgress
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? strings.haveAccountSignIn
                            : strings.noAccountSignUp,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(strings.orDivider),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: login.isInProgress ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: Text(strings.signInWithGoogleButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
