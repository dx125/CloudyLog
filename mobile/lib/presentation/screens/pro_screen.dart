import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/clouding_service.dart';
import '../../services/login_service.dart';
import '../../services/subscription_service.dart';
import '../../services/sync_service.dart';
import 'login_screen.dart';

/// Account & Pro hub: paywall for free users, subscription management for
/// Pro users. Signing in only happens from here — the free tier never needs
/// an account.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  Future<void> _signIn(BuildContext context) async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const LoginScreen()),
    );
    if (signedIn != true || !context.mounted) return;
    // An existing account may already be Pro: pick up its entitlement and
    // reconcile histories right away.
    final subscription = context.read<SubscriptionService>();
    await subscription.refresh();
    if (!context.mounted) return;
    if (subscription.isPro) {
      await _syncAfterUpgrade(context);
    }
  }

  Future<void> _purchase(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    final subscription = context.read<SubscriptionService>();
    final ok = await subscription.purchasePro();
    if (!context.mounted) return;
    if (!ok) {
      _showSnack(context, strings.purchaseFailed);
      return;
    }
    await _syncAfterUpgrade(context);
    if (!context.mounted) return;
    _showSnack(context, strings.purchaseSuccess);
  }

  /// Uploads the device history accumulated on the free tier so stats and
  /// the calendar carry over to the account.
  Future<void> _syncAfterUpgrade(BuildContext context) async {
    final sync = context.read<SyncService>();
    final clouding = context.read<CloudingService>();
    final changed = await sync.syncAll(kLocalProfileId);
    if (changed) {
      await clouding.loadFor(kLocalProfileId);
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.cancelSubscriptionConfirmTitle),
        content: Text(strings.cancelSubscriptionConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.cancelSubscriptionButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await context.read<SubscriptionService>().cancel();
    if (!context.mounted) return;
    _showSnack(
      context,
      ok
          ? AppLocalizations.of(context)!.subscriptionCanceledMessage
          : AppLocalizations.of(context)!.errorNetwork,
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await context.read<LoginService>().signOut();
    if (!context.mounted) return;
    await context.read<SubscriptionService>().clearLocal();
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final login = context.watch<LoginService>();
    final subscription = context.watch<SubscriptionService>();
    final sync = context.watch<SyncService>();

    return Scaffold(
      appBar: AppBar(title: Text(strings.proTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AccountCard(
                login: login,
                onSignIn: () => _signIn(context),
                onSignOut: () => _signOut(context),
              ),
              const SizedBox(height: 16),
              if (subscription.isPro)
                _ManageCard(
                  subscription: subscription,
                  sync: sync,
                  onCancel: () => _cancel(context),
                  onSyncNow: () => _syncAfterUpgrade(context),
                )
              else
                _PaywallCard(
                  subscription: subscription,
                  isLoggedIn: login.isLoggedIn,
                  onSignIn: () => _signIn(context),
                  onPurchase: () => _purchase(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.login,
    required this.onSignIn,
    required this.onSignOut,
  });

  final LoginService login;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = login.currentUser;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.accountHeader, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (user != null) ...[
              Text(strings.signedInAs(user.email)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: Text(strings.signOutButton),
              ),
            ] else ...[
              Text(strings.notSignedIn),
              const SizedBox(height: 4),
              Text(
                strings.freeTierNote,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: Text(strings.signInButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaywallCard extends StatelessWidget {
  const _PaywallCard({
    required this.subscription,
    required this.isLoggedIn,
    required this.onSignIn,
    required this.onPurchase,
  });

  final SubscriptionService subscription;
  final bool isLoggedIn;
  final VoidCallback onSignIn;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  strings.proBenefitsTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Benefit(icon: Icons.cloud_upload, text: strings.proBenefitStorage),
            _Benefit(icon: Icons.leaderboard, text: strings.proBenefitCompare),
            _Benefit(icon: Icons.group, text: strings.proBenefitFriends),
            const SizedBox(height: 12),
            Text(strings.proPriceNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (isLoggedIn)
              FilledButton.icon(
                onPressed: subscription.isInProgress ? null : onPurchase,
                icon: subscription.isInProgress
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.workspace_premium),
                label: Text(strings.subscribeButton),
              )
            else ...[
              Text(
                strings.signInRequiredForPro,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: Text(strings.signInButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.subscription,
    required this.sync,
    required this.onCancel,
    required this.onSyncNow,
  });

  final SubscriptionService subscription;
  final SyncService sync;
  final VoidCallback onCancel;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final status = subscription.status;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final expiresAt = status.expiresAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  strings.manageSubscriptionTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status.status == 'canceled'
                  ? strings.subscriptionStatusCanceled
                  : strings.subscriptionStatusActive,
            ),
            if (expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                strings.expiresOn(
                  DateFormat.yMMMMd(localeTag).format(expiresAt.toLocal()),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: sync.isSyncing ? null : onSyncNow,
                  icon: sync.isSyncing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(strings.syncNowButton),
                ),
                const SizedBox(width: 12),
                if (status.status != 'canceled')
                  TextButton(
                    onPressed: subscription.isInProgress ? null : onCancel,
                    child: Text(strings.cancelSubscriptionButton),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
