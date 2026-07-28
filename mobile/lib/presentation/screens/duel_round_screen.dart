import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../branding/gust.dart';
import '../../domain/duel.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/duel_service.dart';
import '../../services/listen_service.dart';
import '../../theme/puff_theme.dart';
import '../widgets/level_meter.dart';

/// Design C — a live duel round.
///
/// Both phones sit in Listen mode for three minutes while the scores move in
/// something close to real time. This is the one screen where the acoustic
/// detector and duels meet, and it is deliberately framed as **party mode**:
/// a mouth raspberry beats any classifier we can ship, so the copy says so
/// outright rather than implying a verification the product can't perform.
/// Async duels carry the competitive weight; this one carries the fun.
///
/// The three-minute cap is also a capacity decision: Realtime allows ~500
/// messages/second project-wide, which at two clients per duel is roughly 250
/// concurrent rounds. Short rounds keep occupancy low.
class DuelRoundScreen extends StatefulWidget {
  const DuelRoundScreen({super.key, required this.duelId});

  final String duelId;

  @override
  State<DuelRoundScreen> createState() => _DuelRoundScreenState();
}

class _DuelRoundScreenState extends State<DuelRoundScreen> {
  ListenService? _listen;
  DuelService? _duels;
  Timer? _ticker;
  DateTime? _endsAt;
  int _lastSeenDetections = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen ??= context.read<ListenService>()..addListener(_onDetections);
    _duels ??= context.read<DuelService>();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _listen?.removeListener(_onDetections);
    _listen?.stop();
    _duels?.stopLive();
    super.dispose();
  }

  Future<void> _begin() async {
    if (!mounted) return;
    final duels = context.read<DuelService>();
    final duel = _find(duels);
    if (duel == null) return;

    _endsAt = duel.endsAt;
    await duels.startLive(duel);
    if (!mounted) return;
    await context.read<ListenService>().start(mode: ListenMode.duel);

    // Drives the countdown and ends the round on time.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final ends = _endsAt;
      if (ends != null && !DateTime.now().isBefore(ends)) _finish();
    });
  }

  /// ListenService counts detections; the duel needs them as they arrive so the
  /// local score renders instantly and the throttled broadcast catches up.
  void _onDetections() {
    final listen = _listen;
    final duels = _duels;
    if (listen == null || duels == null) return;
    while (_lastSeenDetections < listen.sessionCount) {
      _lastSeenDetections++;
      duels.recordLiveDetection();
    }
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _ticker = null;
    final duels = _duels;
    final listen = _listen;
    await listen?.stop();
    await duels?.stopLive();

    if (duels != null) {
      final duel = _find(duels);
      // The authoritative score goes through the edge function, never a
      // broadcast a peer could forge.
      if (duel != null) {
        await duels.submitScore(duel);
        await duels.refresh();
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Duel? _find(DuelService duels) {
    for (final duel in duels.duels) {
      if (duel.id == widget.duelId) return duel;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final listen = context.watch<ListenService>();
    final duels = context.watch<DuelService>();
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    final ends = _endsAt;
    final left =
        ends == null ? Duration.zero : ends.difference(DateTime.now());
    final remaining = left.isNegative ? Duration.zero : left;
    final opponentTotal = duels.liveOpponents.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: puff.canvas,
      appBar: AppBar(
        backgroundColor: puff.canvas,
        title: Text(strings.duelRoundTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Text(
              '${remaining.inMinutes}:'
              '${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
              style: theme.textTheme.displayLarge!.copyWith(fontSize: 40),
            ),
            const SizedBox(height: 4),
            Text(strings.duelRoundHint, style: theme.textTheme.bodySmall),
            const Spacer(),
            AnimatedScale(
              scale: reducedMotion
                  ? 1.0
                  : 1 + (listen.level.clamp(0.0, 1.0) * 0.18),
              duration: const Duration(milliseconds: 120),
              child: Gust(body: puff.action, face: puff.canvas, size: 96),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Score(label: strings.duelYou, value: duels.liveCount),
                _Score(label: '—', value: opponentTotal),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: LevelMeter(level: listen.level),
            ),
            const Spacer(),
            // The honest disclaimer, and the screen's one joke.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                strings.duelRoundHonour,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _finish,
                  child: Text(strings.duelRoundEnd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puff = context.puff;

    return Column(
      children: [
        Text('$value',
            style: theme.textTheme.displayLarge!
                .copyWith(fontSize: 44, color: puff.action)),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
