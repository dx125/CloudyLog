import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../branding/gust.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/sync_service.dart';
import '../../theme/puff_theme.dart';
import 'create_account_dialog.dart';
import 'pill_button.dart';

/// The paywall. Appears only at moments of earned curiosity — never between
/// the user and the tap button. Returns true when Pro was activated.
Future<bool> showPaywall(BuildContext context) async {
  final purchased = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PaywallSheet(),
  );
  return purchased ?? false;
}

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet();

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  bool _busy = false;

  Future<void> _purchase() async {
    final strings = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    final entitlements = context.read<EntitlementService>();
    final sync = context.read<SyncService>();

    setState(() => _busy = true);
    // Purchases are account-bound. First make sure a session exists, then make
    // sure it's a *real* one: an anonymous user can't own a subscription, so a
    // still-anonymous purchaser signs in (email + password) before we charge.
    final hasSession = await auth.ensureSession();
    if (!mounted) return;
    if (hasSession && auth.isAnonymous) {
      final created = await showCreateAccountDialog(context);
      if (!mounted) return;
      if (!created) {
        // No account, no subscription. The dialog already reported any
        // failure, and cancelling is a normal choice — bail quietly.
        setState(() => _busy = false);
        return;
      }
    }
    final purchased = hasSession && await entitlements.purchasePro();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!purchased) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.purchaseFailed)),
      );
      return;
    }
    // First sync: the whole on-device history rides up in the background.
    sync.schedulePush();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.purchaseSuccess)),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Gust(body: puff.action, face: puff.surface, size: 84)),
            const SizedBox(height: 12),
            Text(
              strings.proHeader,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              strings.paywallLead,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            _benefit(context, Icons.cloud_outlined, strings.paywallBenefitHistory),
            _benefit(context, Icons.insights_outlined, strings.paywallBenefitStats),
            _benefit(context, Icons.emoji_events_outlined, strings.paywallBenefitBadges),
            _benefit(context, Icons.restaurant_outlined, strings.paywallBenefitSoon),
            const SizedBox(height: 14),
            Text(
              strings.paywallPrice,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              strings.paywallDevNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Center(
              child: PillButton(
                label: strings.goProButton,
                icon: Icons.workspace_premium_outlined,
                color: puff.pro,
                pillowColor: puff.proPillow,
                foregroundColor: puff.onPro,
                enabled: !_busy,
                onPressed: _purchase,
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: Text(strings.maybeLaterButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.puff.action),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
