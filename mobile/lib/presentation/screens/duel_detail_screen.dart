import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/duel.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/duel_service.dart';
import '../../theme/puff_theme.dart';
import 'duel_round_screen.dart';
import 'duels_screen.dart';

/// One duel: the scoreboard, the join code, and the way into a live round.
class DuelDetailScreen extends StatefulWidget {
  const DuelDetailScreen({super.key, required this.duelId});

  final String duelId;

  @override
  State<DuelDetailScreen> createState() => _DuelDetailScreenState();
}

class _DuelDetailScreenState extends State<DuelDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScore());
  }

  /// Push my current standing before showing the board, so the user isn't
  /// looking at a stale number they know is wrong.
  Future<void> _syncScore() async {
    if (!mounted) return;
    final duels = context.read<DuelService>();
    final duel = _find(duels);
    if (duel == null) return;
    await duels.submitScore(duel);
    if (mounted) await duels.refresh();
  }

  Duel? _find(DuelService duels) {
    for (final duel in duels.duels) {
      if (duel.id == widget.duelId) return duel;
    }
    return null;
  }

  Future<void> _leave(Duel duel) async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(strings.duelLeaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.duelLeave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<DuelService>().leave(duel.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final duels = context.watch<DuelService>();
    final duel = _find(duels);

    if (duel == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final over = duel.isOver(now);

    return Scaffold(
      backgroundColor: puff.canvas,
      appBar: AppBar(
        backgroundColor: puff.canvas,
        title: Text(duel.name),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          children: [
            Text(
              duelTimeLine(strings, duel, now),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 14),

            // The invite. A six-character code shared as text needs no
            // deep-link infrastructure and works in any chat app.
            GestureDetector(
              onTap: () => copyDuelCode(context, duel.code),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: puff.surface,
                  borderRadius: BorderRadius.circular(PuffRadius.md),
                  border: Border.all(color: puff.hairline),
                ),
                child: Row(
                  children: [
                    Text(
                      strings.duelCodeLabel.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                    const Spacer(),
                    Text(
                      duel.code,
                      style: theme.textTheme.headlineMedium!.copyWith(
                        fontSize: 20,
                        letterSpacing: 3,
                        color: puff.action,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded, size: 16, color: puff.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              duelStandingLine(strings, duel),
              style: theme.textTheme.bodyMedium!
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final score in duel.standings)
              _ScoreRow(score: score, kind: duel.kind),

            const SizedBox(height: 22),
            if (duel.kind == DuelKind.live && !over)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DuelRoundScreen(duelId: duel.id),
                    ),
                  ),
                  child: Text(strings.duelStartRound),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _leave(duel),
              child: Text(strings.duelLeave),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.score, required this.kind});

  final DuelScore score;
  final DuelKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puff = context.puff;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(score.name, style: theme.textTheme.bodyLarge)),
          Text(
            '${score.pointsFor(kind)}',
            style: theme.textTheme.headlineMedium!.copyWith(
              fontSize: 21,
              color: puff.action,
            ),
          ),
        ],
      ),
    );
  }
}
