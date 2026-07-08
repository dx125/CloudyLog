import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../branding/gust.dart';
import '../../domain/badges.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/settings_service.dart';
import '../../services/stats_service.dart';
import '../../services/sync_service.dart';
import '../../services/tap_service.dart';
import '../../theme/puff_theme.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/pill_button.dart';
import '../widgets/share_cards.dart';
import 'diagnostics_screen.dart';

/// Profile hub: streaks and totals, the badge collection, Wrapped, Pro
/// management, account (anonymous → email upgrade), settings and the privacy
/// promise.
class YouScreen extends StatefulWidget {
  const YouScreen({super.key});

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen> {
  late Future<StatsSnapshot> _statsFuture;
  TapService? _tapService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tap = context.read<TapService>();
    if (tap != _tapService) {
      _tapService?.removeListener(_reload);
      _tapService = tap..addListener(_reload);
      _statsFuture = context.read<StatsService>().snapshot();
    }
  }

  @override
  void dispose() {
    _tapService?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _statsFuture = context.read<StatsService>().snapshot();
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _shareWrapped() async {
    final strings = AppLocalizations.of(context)!;
    final wrapped = await context.read<StatsService>().wrapped();
    if (!mounted) return;
    if (wrapped.totalCount == 0) {
      _snack(strings.wrappedNoData);
      return;
    }
    await showShareCardDialog(
      context,
      headline: strings.wrappedTitle(wrapped.year),
      lines: [
        strings.wrappedTotal(wrapped.totalCount),
        strings.wrappedBestDay(wrapped.bestDayCount),
        strings.wrappedStreak(wrapped.longestStreak),
        if (wrapped.topTag != null) strings.wrappedTopTag(wrapped.topTag!),
      ],
      shareText: strings.shareWrappedText,
    );
  }

  Future<void> _shareBadge(String name) async {
    final strings = AppLocalizations.of(context)!;
    await showShareCardDialog(
      context,
      headline: name,
      lines: [strings.shareBadgeText(name)],
      shareText: strings.shareBadgeText(name),
    );
  }

  Future<void> _createAccount() async {
    final strings = AppLocalizations.of(context)!;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.createAccountButton),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: strings.emailLabel),
                validator: (v) =>
                    (v ?? '').contains('@') ? null : strings.emailInvalid,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.passwordLabel),
                validator: (v) =>
                    (v ?? '').length >= 8 ? null : strings.passwordTooShort,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: Text(strings.createAccountButton),
          ),
        ],
      ),
    );

    if (submitted == true && mounted) {
      final ok = await context.read<AuthService>().upgrade(
            email: emailController.text.trim(),
            password: passwordController.text,
          );
      if (mounted) {
        _snack(ok ? strings.accountCreated : strings.accountUpgradeFailed);
      }
    }
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _cancelPro() async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.cancelProConfirmTitle),
        content: Text(strings.cancelProConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.cancelProButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<EntitlementService>().cancelPro();
    if (mounted) {
      _snack(ok ? strings.proCanceledMessage : strings.errorNetwork);
    }
  }

  Future<void> _deleteCloudData() async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteConfirmTitle),
        content: Text(strings.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.puff.pro,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.deleteAccountButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<AuthService>().deleteAccount();
    if (!mounted) return;
    if (ok) {
      await context.read<EntitlementService>().clearLocal();
      if (mounted) _snack(strings.deleteDone);
    } else {
      _snack(strings.errorNetwork);
    }
  }

  Future<void> _syncNow() async {
    final strings = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    final sync = context.read<SyncService>();
    await auth.ensureSession();
    final ok = await sync.pushPending();
    if (mounted) _snack(ok ? strings.syncDone : strings.errorNetwork);
  }

  Future<void> _restore() async {
    final strings = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    final sync = context.read<SyncService>();
    final tap = context.read<TapService>();
    await auth.ensureSession();
    final ok = await sync.restoreFromCloud();
    if (ok) await tap.refreshIfStale();
    _reload();
    if (mounted) _snack(ok ? strings.restoreDone : strings.errorNetwork);
  }

  String _badgeName(AppLocalizations strings, String id) => switch (id) {
        'first_puff' => strings.badgeFirstPuff,
        'double_digits' => strings.badgeDoubleDigits,
        'streak_3' => strings.badgeStreak3,
        'streak_7' => strings.badgeStreak7,
        'streak_30' => strings.badgeStreak30,
        'century' => strings.badgeCentury,
        'gale_force' => strings.badgeGaleForce,
        'tag_collector' => strings.badgeTagCollector,
        'regular' => strings.badgeRegular,
        _ => id,
      };

  String _badgeDesc(AppLocalizations strings, String id) => switch (id) {
        'first_puff' => strings.badgeFirstPuffDesc,
        'double_digits' => strings.badgeDoubleDigitsDesc,
        'streak_3' => strings.badgeStreak3Desc,
        'streak_7' => strings.badgeStreak7Desc,
        'streak_30' => strings.badgeStreak30Desc,
        'century' => strings.badgeCenturyDesc,
        'gale_force' => strings.badgeGaleForceDesc,
        'tag_collector' => strings.badgeTagCollectorDesc,
        'regular' => strings.badgeRegularDesc,
        _ => id,
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final entitlements = context.watch<EntitlementService>();
    final auth = context.watch<AuthService>();
    final settings = context.watch<SettingsService>();
    final sync = context.watch<SyncService>();
    final isPro = entitlements.isPro;
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Text(strings.youTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 14),

          // Totals header.
          _card(
            context,
            child: FutureBuilder<StatsSnapshot>(
              future: _statsFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                final streak = data?.currentStreak ?? 0;
                return Row(
                  children: [
                    Gust(body: puff.action, face: puff.surface, size: 72),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.totalToots(data?.totalCount ?? 0),
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.bestDayLabel(data?.bestDayCount ?? 0),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (streak > 0) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => showShareCardDialog(
                                context,
                                headline:
                                    strings.shareCardStreakHeadline(streak),
                                lines: [strings.shareStreakText(streak)],
                                shareText: strings.shareStreakText(streak),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: puff.streakBg,
                                  borderRadius:
                                      BorderRadius.circular(PuffRadius.pill),
                                ),
                                child: Text(
                                  strings.streakPill(data!.currentStreak),
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: puff.streakFg,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Badge collection.
          _card(
            context,
            title: strings.badgesHeader,
            child: FutureBuilder<StatsSnapshot>(
              future: _statsFuture,
              builder: (context, snapshot) {
                final facts = snapshot.data?.badgeFacts;
                if (facts == null) return const SizedBox(height: 40);
                return Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final badge in kBadges)
                      _BadgeTile(
                        emoji: badge.emoji,
                        name: _badgeName(strings, badge.id),
                        description: _badgeDesc(strings, badge.id),
                        earned: badge.earned(facts),
                        locked: !badge.inBasicSet && !isPro,
                        onOpenPaywall: () => showPaywall(context),
                        onShare: () =>
                            _shareBadge(_badgeName(strings, badge.id)),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Wrapped.
          _card(
            context,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.wrappedButton,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: puff.action,
                    foregroundColor: puff.onAction,
                  ),
                  onPressed: _shareWrapped,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(strings.shareButton),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pro.
          _card(
            context,
            title: strings.proHeader,
            child: isPro
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entitlements.entitlement?.status == 'canceled'
                            ? strings.proStatusCanceled
                            : strings.proStatusActive,
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (entitlements.entitlement != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          strings.proValidUntil(
                            DateFormat.yMMMd(localeTag).format(
                              entitlements.entitlement!.expiresAt.toLocal(),
                            ),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: sync.isSyncing ? null : _syncNow,
                            icon: const Icon(Icons.sync, size: 18),
                            label: Text(strings.syncNowButton),
                          ),
                          OutlinedButton.icon(
                            onPressed: sync.isSyncing ? null : _restore,
                            icon: const Icon(Icons.cloud_download_outlined,
                                size: 18),
                            label: Text(strings.restoreButton),
                          ),
                          if (entitlements.entitlement?.status != 'canceled')
                            TextButton(
                              onPressed: entitlements.isInProgress
                                  ? null
                                  : _cancelPro,
                              child: Text(strings.cancelProButton),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.paywallDevNote,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.paywallLead,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      PillButton(
                        label: strings.goProButton,
                        icon: Icons.workspace_premium_outlined,
                        color: puff.pro,
                        pillowColor: puff.proPillow,
                        foregroundColor: puff.onPro,
                        onPressed: () => showPaywall(context),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Account.
          _card(
            context,
            title: strings.accountHeader,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.account?.email != null
                      ? strings.accountEmail(auth.account!.email!)
                      : strings.accountAnonymous,
                  style: theme.textTheme.bodyLarge,
                ),
                if (auth.account?.email == null) ...[
                  const SizedBox(height: 2),
                  Text(
                    strings.accountUpgradeHint,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _createAccount,
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    label: Text(strings.createAccountButton),
                  ),
                ],
                if (auth.hasSession) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _deleteCloudData,
                    style: TextButton.styleFrom(foregroundColor: puff.pro),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(strings.deleteAccountButton),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Settings.
          _card(
            context,
            title: strings.settingsHeader,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.themeSetting, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(strings.themeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(strings.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(strings.themeDark),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) =>
                      settings.setThemeMode(selection.first),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    strings.soundSetting,
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    strings.soundSettingHint,
                    style: theme.textTheme.bodySmall,
                  ),
                  value: settings.soundEnabled,
                  onChanged: settings.setSoundEnabled,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    strings.diagnosticsSetting,
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    strings.diagnosticsSettingHint,
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: puff.textSecondary,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DiagnosticsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              strings.privacyNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {String? title, required Widget child}) {
    final puff = context.puff;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: puff.surface,
        borderRadius: BorderRadius.circular(PuffRadius.lg),
        border: Border.all(color: puff.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.emoji,
    required this.name,
    required this.description,
    required this.earned,
    required this.locked,
    required this.onOpenPaywall,
    required this.onShare,
  });

  final String emoji;
  final String name;
  final String description;
  final bool earned;

  /// Part of the Pro-only full collection while the user is free.
  final bool locked;
  final VoidCallback onOpenPaywall;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    final theme = Theme.of(context);
    final showEarned = earned && !locked;

    return GestureDetector(
      onTap: locked
          ? onOpenPaywall
          : showEarned
              ? onShare
              : null,
      child: Tooltip(
        message: description,
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: showEarned ? puff.chipSelectedBg : puff.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: showEarned
                            ? puff.chipSelectedBorder
                            : puff.hairline,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: showEarned ? 1 : 0.35,
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
                  if (locked)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: puff.pro,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.proChip,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: puff.onPro,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  color:
                      showEarned ? puff.textPrimary : puff.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
