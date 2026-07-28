import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../branding/gust.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/entitlement_service.dart';
import '../../services/listen_service.dart';
import '../../theme/puff_theme.dart';
import '../widgets/level_meter.dart';
import '../widgets/paywall_sheet.dart';

/// Design B — Listen mode.
///
/// A session the user *enters*, never something running in the background. That
/// single decision buys the clean permission story, the predictable battery
/// cost, and freedom from Android's foreground-service declarations all at once.
///
/// Every detection is dismissible. The classifier will be wrong sometimes, and
/// the honest response is to make being wrong cheap rather than to pretend it
/// won't happen.
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  ListenService? _listen;
  bool _paywallShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ListenService>().start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final listen = context.read<ListenService>();
    if (listen != _listen) {
      _listen?.removeListener(_onListenChanged);
      _listen = listen..addListener(_onListenChanged);
    }
  }

  @override
  void dispose() {
    _listen?.removeListener(_onListenChanged);
    // Leaving the screen always releases the microphone. Can't be awaited from
    // dispose; it lands an event-loop turn later, which is soon enough.
    _listen?.stop();
    super.dispose();
  }

  void _onListenChanged() {
    final listen = _listen;
    if (listen == null || !mounted) return;
    // The free session running out is a paywall moment at a peak of
    // engagement — not a wall in front of the feature. The session already
    // happened; Pro buys the next one being longer.
    if (listen.budgetExhausted && !_paywallShown) {
      _paywallShown = true;
      showPaywall(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final listen = context.watch<ListenService>();
    final isPro = context.watch<EntitlementService>().isPro;
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: puff.canvas,
      appBar: AppBar(
        backgroundColor: puff.canvas,
        title: Text(strings.listenTitle),
        actions: [
          if (!isPro && listen.remaining != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  strings.listenBudgetLeft(listen.remaining!.inSeconds),
                  style: theme.textTheme.bodySmall!
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (listen.state) {
          ListenState.permissionDenied => _Message(
              title: strings.listenDeniedTitle,
              body: strings.listenDeniedBody,
            ),
          ListenState.error => _Message(
              title: strings.listenErrorTitle,
              body: strings.listenErrorBody,
            ),
          _ => _Session(listen: listen, reducedMotion: reducedMotion),
        },
      ),
    );
  }
}

class _Session extends StatelessWidget {
  const _Session({required this.listen, required this.reducedMotion});

  final ListenService listen;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;

    // Gust swells with the room. Under reduced motion he holds still — the
    // level meter still moves, so nothing is lost.
    final scale = reducedMotion ? 1.0 : 1 + (listen.level.clamp(0.0, 1.0) * 0.18);

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            strings.listenIntro,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const Spacer(),
        AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          child: Gust(body: puff.action, face: puff.canvas, size: 120),
        ),
        const SizedBox(height: 18),
        Text('${listen.sessionCount}', style: theme.textTheme.displayLarge),
        Text(
          strings.listenHeardLabel,
          style:
              theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: LevelMeter(level: listen.level),
        ),
        const Spacer(),
        Expanded(
          flex: 3,
          child: listen.detections.isEmpty
              ? Center(
                  child: Text(
                    strings.listenEmpty,
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : _DetectionList(listen: listen),
        ),
        // The one joke on this screen (voice rule: one per screen).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Text(
            strings.listenSilentJoke,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(strings.listenStop),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetectionList extends StatelessWidget {
  const _DetectionList({required this.listen});

  final ListenService listen;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final time = DateFormat.Hms(Localizations.localeOf(context).toLanguageTag());
    final newestFirst = listen.detections.reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: newestFirst.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final detection = newestFirst[index];
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: puff.surface,
            borderRadius: BorderRadius.circular(PuffRadius.md),
            border: Border.all(color: puff.hairline),
          ),
          child: Row(
            children: [
              Text(
                time.format(detection.at),
                style: theme.textTheme.bodySmall!
                    .copyWith(fontFeatures: const []),
              ),
              const SizedBox(width: 12),
              if (detection.tag != null)
                Text(
                  detection.tag!,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: puff.action,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => listen.undo(detection.id),
                child: Text(strings.listenUndo),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puff = context.puff;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Gust(body: puff.textSecondary, face: puff.canvas, size: 96),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
