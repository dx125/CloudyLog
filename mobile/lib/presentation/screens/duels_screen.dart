import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../branding/gust.dart';
import '../../domain/duel.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/duel_service.dart';
import '../../services/entitlement_service.dart';
import '../../theme/puff_theme.dart';
import '../widgets/paywall_sheet.dart';
import 'duel_detail_screen.dart';

/// Duels — async weeks and live rounds in one list.
///
/// Joining is free and creating is Pro (enforced in RLS, not here): the person
/// you invite is the acquisition, so the invitation must never hit a paywall.
class DuelsScreen extends StatefulWidget {
  const DuelsScreen({super.key});

  @override
  State<DuelsScreen> createState() => _DuelsScreenState();
}

class _DuelsScreenState extends State<DuelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DuelService>().refresh();
    });
  }

  Future<void> _create(DuelKind kind) async {
    final duels = context.read<DuelService>();
    final strings = AppLocalizations.of(context)!;

    final duel = await duels.create(kind: kind);
    if (!mounted) return;
    if (duel == null) {
      // Creating is Pro-gated server-side; a refusal is a paywall moment.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.duelProOnly)),
      );
      await showPaywall(context);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DuelDetailScreen(duelId: duel.id)),
    );
  }

  Future<void> _join() async {
    final strings = AppLocalizations.of(context)!;
    final duels = context.read<DuelService>();
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.duelJoinTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: strings.duelJoinHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(strings.duelJoinButton),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;

    final joined = await duels.join(code.trim());
    if (!mounted) return;
    if (joined) return;

    // A full free tier and a wrong code need different answers: one offers
    // Pro, the other just says the code is no good.
    if (duels.limitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.duelJoinLimit)),
      );
      await showPaywall(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.duelJoinNotFound)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final duels = context.watch<DuelService>();
    final isPro = context.watch<EntitlementService>().isPro;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: duels.duels.isEmpty
                ? _Empty(loading: duels.isLoading)
                : RefreshIndicator(
                    onRefresh: duels.refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                      itemCount: duels.duels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _DuelCard(
                        duel: duels.duels[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DuelDetailScreen(duelId: duels.duels[i].id),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _create(DuelKind.async),
                        child: Text(strings.duelCreateAsync),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _create(DuelKind.live),
                        child: Text(strings.duelCreateLive),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _join,
                    child: Text(strings.duelJoin),
                  ),
                ),
                if (!isPro)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      strings.duelProOnly,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingGust(
              child: Gust(body: puff.action, face: puff.canvas, size: 120),
            ),
            const SizedBox(height: 22),
            Text(
              strings.duelsEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              strings.duelsEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DuelCard extends StatelessWidget {
  const _DuelCard({required this.duel, required this.onTap});

  final Duel duel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final now = DateTime.now();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: puff.surface,
          borderRadius: BorderRadius.circular(PuffRadius.md),
          border: Border.all(color: puff.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    duel.name,
                    style: theme.textTheme.headlineMedium!.copyWith(fontSize: 19),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: puff.canvas,
                    borderRadius: BorderRadius.circular(PuffRadius.pill),
                    border: Border.all(color: puff.hairline),
                  ),
                  child: Text(
                    duel.kind == DuelKind.live
                        ? strings.duelKindLive
                        : strings.duelKindAsync,
                    style: theme.textTheme.labelSmall!.copyWith(fontSize: 10.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              duelStandingLine(strings, duel),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              duelTimeLine(strings, duel, now),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Who's ahead, in words. Shared by the card and the detail screen.
String duelStandingLine(AppLocalizations strings, Duel duel) {
  if (duel.scores.length < 2) return strings.duelWaiting;
  final leader = duel.leader;
  if (leader == null) return strings.duelTied;
  return strings.duelLeading(leader.name);
}

String duelTimeLine(AppLocalizations strings, Duel duel, DateTime now) {
  if (duel.isOver(now)) return strings.duelOver;
  final left = duel.remaining(now);
  if (left.inDays >= 1) return strings.duelTimeLeftDays(left.inDays);
  if (left.inHours >= 1) return strings.duelTimeLeftHours(left.inHours);
  return strings.duelTimeLeftMinutes(left.inMinutes);
}

/// Copies a join code to the clipboard — the whole invite mechanism. Six
/// characters over any chat app beats deep-link infrastructure we'd have to
/// build, host and debug.
Future<void> copyDuelCode(BuildContext context, String code) async {
  final strings = AppLocalizations.of(context)!;
  await Clipboard.setData(ClipboardData(text: code));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(strings.duelCodeCopied)),
  );
}
