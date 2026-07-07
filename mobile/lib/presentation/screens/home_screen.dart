import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/clouding_service.dart';
import '../../services/config_service.dart';
import '../../services/login_service.dart';
import '../../services/share_service.dart';
import '../../services/subscription_service.dart';
import '../widgets/clouding_progress_bar.dart';
import 'calendar_screen.dart';
import 'friends_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Catch the case where the user opened the app from a recent run that
    // crossed midnight while suspended.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CloudingService>().refreshIfStale();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CloudingService>().refreshIfStale();
    }
  }

  Future<void> _share(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    final clouding = context.read<CloudingService>();
    final config = context.read<ConfigService>();
    final shareService = context.read<ShareService>();

    final message = strings.shareMessage(
      clouding.todayCount,
      config.recommendedDailyCount,
    );
    await shareService.shareText(message, subject: strings.shareSubject);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.resetConfirmTitle),
        content: Text(strings.resetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.resetTodayButton),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      if (!context.mounted) return;
      await context.read<CloudingService>().resetToday();
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  String _resolveDisplayName(ConfigService config, LoginService login) {
    if (config.displayName.isNotEmpty) return config.displayName;
    return login.currentUser?.displayName ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final clouding = context.watch<CloudingService>();
    final config = context.watch<ConfigService>();
    final login = context.watch<LoginService>();
    final subscription = context.watch<SubscriptionService>();
    final displayName = _resolveDisplayName(config, login);
    final isPro = subscription.isPro;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.homeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: strings.shareTooltip,
            onPressed: () => _share(context),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: strings.calendarTooltip,
            onPressed: () => _push(context, const CalendarScreen()),
          ),
          if (isPro) ...[
            IconButton(
              icon: const Icon(Icons.leaderboard),
              tooltip: strings.statsTooltip,
              onPressed: () => _push(context, const StatsScreen()),
            ),
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: strings.friendsTooltip,
              onPressed: () => _push(context, const FriendsScreen()),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: strings.settingsTooltip,
            onPressed: () => _push(context, const SettingsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: strings.resetTodayButton,
            onPressed: () => _confirmReset(context),
          ),
          IconButton(
            icon: Icon(
              isPro ? Icons.verified : Icons.workspace_premium,
              color: isPro ? theme.colorScheme.primary : null,
            ),
            tooltip: strings.proTooltip,
            onPressed: () => _push(context, const ProScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (displayName.isNotEmpty)
                Text(
                  strings.greeting(displayName),
                  style: theme.textTheme.titleLarge,
                ),
              const SizedBox(height: 8),
              Text(
                strings.todaysCloudingsLabel,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${clouding.todayCount}',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.recommendedLabel(config.recommendedDailyCount),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              CloudingProgressBar(
                current: clouding.todayCount,
                goal: config.recommendedDailyCount,
              ),
              const Spacer(),
              if (!isPro)
                TextButton.icon(
                  onPressed: () => _push(context, const ProScreen()),
                  icon: const Icon(Icons.workspace_premium),
                  label: Text(strings.upgradeButton),
                ),
              FilledButton.tonalIcon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share),
                label: Text(strings.shareButton),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.read<CloudingService>().increment(),
        icon: const Icon(Icons.add),
        label: Text(strings.incrementButton),
        tooltip: strings.incrementTooltip,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
