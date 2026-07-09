import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/percentile.dart';
import '../../domain/puff_event.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/entitlement_service.dart';
import '../../services/global_stats_service.dart';
import '../../services/stats_service.dart';
import '../../services/tap_service.dart';
import '../../theme/puff_theme.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/week_chart.dart';

/// Free: week chart, the live world comparison, 7 days of history. Pro adds
/// the full history heatmap, time-of-day and weekday patterns. Locked charts
/// are the paywall's "earned curiosity" moments.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<StatsSnapshot> _snapshotFuture;
  late Future<List<int>> _hoursFuture;
  late Future<List<double>> _weekdaysFuture;
  TapService? _tapService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tap = context.read<TapService>();
    if (tap != _tapService) {
      _tapService?.removeListener(_reload);
      _tapService = tap..addListener(_reload);
      _reload();
    }
  }

  @override
  void dispose() {
    _tapService?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    final stats = context.read<StatsService>();
    final globalStats = context.read<GlobalStatsService>();
    setState(() {
      _snapshotFuture = stats.snapshot();
      _hoursFuture = stats.hourHistogram();
      _weekdaysFuture = stats.weekdayAverages();
    });
    // refresh() notifies listeners; _reload runs from didChangeDependencies
    // (and the shell's IndexedStack builds every tab eagerly), so calling it
    // inline would fire notifyListeners during build. Defer past the frame.
    // TTL-guarded; a failed fetch is recorded at the gateway and the card
    // degrades to the sourced range.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) globalStats.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isPro = context.watch<EntitlementService>().isPro;
    final todayCount = context.watch<TapService>().todayCount;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Text(strings.statsTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 14),
          _WorldCard(todayCount: todayCount),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.thisWeek,
            child: FutureBuilder<StatsSnapshot>(
              future: _snapshotFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (data == null) return const _CardLoading();
                if (data.weekTotal == 0) {
                  return Text(
                    strings.statsEmptyDay,
                    style: theme.textTheme.bodyMedium,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WeekChart(counts: data.weekCounts, height: 56),
                    const SizedBox(height: 8),
                    Text(
                      strings.weekTotal(data.weekTotal),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: strings.statsHistory,
            child: FutureBuilder<StatsSnapshot>(
              future: _snapshotFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (data == null) return const _CardLoading();
                return _HistoryGrid(
                  dayCounts: data.dayCounts,
                  isPro: isPro,
                  lockedNote: strings.historyLockedNote,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (isPro)
            _SectionCard(
              title: strings.statsTimeOfDay,
              subtitle: strings.statsTimeOfDayHint,
              child: FutureBuilder<List<int>>(
                future: _hoursFuture,
                builder: (context, snapshot) {
                  final hours = snapshot.data;
                  if (hours == null) return const _CardLoading();
                  return WeekChart(
                    counts: hours,
                    height: 48,
                    hotIndex: _maxIndex(hours),
                  );
                },
              ),
            )
          else
            _LockedCard(
              title: strings.statsTimeOfDay,
              description: strings.statsTimeOfDayHint,
            ),
          const SizedBox(height: 12),
          if (isPro)
            _SectionCard(
              title: strings.statsWeekday,
              subtitle: strings.statsWeekdayHint,
              child: FutureBuilder<List<double>>(
                future: _weekdaysFuture,
                builder: (context, snapshot) {
                  final averages = snapshot.data;
                  if (averages == null) return const _CardLoading();
                  final scaled = [
                    for (final avg in averages) (avg * 10).round(),
                  ];
                  return WeekChart(
                    counts: scaled,
                    height: 48,
                    hotIndex: _maxIndex(scaled),
                  );
                },
              ),
            )
          else
            _LockedCard(
              title: strings.statsWeekday,
              description: strings.statsWeekdayHint,
            ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              strings.disclaimer,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  int _maxIndex(List<int> values) {
    var index = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[index]) index = i;
    }
    return index;
  }
}

/// Live world comparison — free tier included: the backend aggregate is
/// anonymous and every client contributes its daily count, so everyone gets
/// to see where they land.
class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.todayCount});

  final int todayCount;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final globalStats = context.watch<GlobalStatsService>();
    final global = globalStats.latest;

    return _SectionCard(
      title: strings.statsTodayVsWorld,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$todayCount', style: theme.textTheme.displayMedium),
          const SizedBox(height: 4),
          Text(strings.statsWorldRange, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 10),
          if (global == null && globalStats.isLoading)
            const _CardLoading()
          else if (global == null || global.totalUsers == 0)
            Text(
              strings.statsNoGlobalData,
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: puff.chipSelectedBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                strings.statsPercentile(
                  percentileRankFor(todayCount, global.distribution),
                ),
                style: theme.textTheme.titleMedium!
                    .copyWith(color: puff.chipSelectedBorder),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.statsParticipants(global.totalUsers),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// 12 weeks of history as a heat grid, most recent week at the bottom. Free
/// sees only the last 7 days; the older cells are the day-8 paywall moment.
class _HistoryGrid extends StatelessWidget {
  const _HistoryGrid({
    required this.dayCounts,
    required this.isPro,
    required this.lockedNote,
  });

  final Map<DateTime, int> dayCounts;
  final bool isPro;
  final String lockedNote;

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    final theme = Theme.of(context);
    final today = dayOf(DateTime.now());
    // Align the grid so the last row ends on today.
    const weeks = 12;
    final start = today.subtract(const Duration(days: weeks * 7 - 1));
    var max = 0;
    for (final count in dayCounts.values) {
      if (count > max) max = count;
    }

    final rows = <Widget>[];
    for (var w = 0; w < weeks; w++) {
      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = start.add(Duration(days: w * 7 + d));
        final count = dayCounts[day] ?? 0;
        final withinFreeWindow =
            today.difference(day).inDays < 7 && !day.isAfter(today);
        final visible = isPro || withinFreeWindow;
        final Color color;
        if (!visible) {
          color = puff.hairline.withValues(alpha: 0.55);
        } else if (count == 0) {
          color = puff.hairline;
        } else {
          color = Color.lerp(
            puff.barIdle,
            puff.barHot,
            max == 0 ? 0 : count / max,
          )!;
        }
        cells.add(
          Expanded(
            child: GestureDetector(
              onTap: visible ? null : () => showPaywall(context),
              child: Container(
                height: 16,
                margin: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        );
      }
      rows.add(Row(children: cells));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        if (!isPro) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showPaywall(context),
            child: Text(lockedNote, style: theme.textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text(title, style: theme.textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    return GestureDetector(
      onTap: () => showPaywall(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: puff.surface,
          borderRadius: BorderRadius.circular(PuffRadius.lg),
          border: Border.all(color: puff.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: theme.textTheme.titleLarge),
                      ),
                      const SizedBox(width: 8),
                      _ProChip(label: strings.proChip),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    strings.lockedProCard,
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: puff.pro, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Icon(Icons.lock_outline, color: puff.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  const _ProChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: puff.pro,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: puff.onPro,
        ),
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

