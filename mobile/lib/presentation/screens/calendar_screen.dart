import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../domain/goal_status.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/clouding_service.dart';
import '../../services/config_service.dart';
import '../utils/goal_status_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Future<Map<DateTime, int>> _historyFuture =
      Future.value(const <DateTime, int>{});
  CloudingService? _service;
  DateTime _focusedDay = _startOfDay(DateTime.now());
  DateTime _selectedDay = _startOfDay(DateTime.now());

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newService = context.read<CloudingService>();
    if (newService != _service) {
      _service?.removeListener(_reloadHistory);
      _service = newService;
      _service!.addListener(_reloadHistory);
      _reloadHistory();
    }
  }

  @override
  void dispose() {
    _service?.removeListener(_reloadHistory);
    super.dispose();
  }

  void _reloadHistory() {
    if (!mounted || _service == null) return;
    setState(() {
      _historyFuture = _service!.fetchHistory();
    });
  }

  int _countFor(Map<DateTime, int> history, DateTime day) =>
      history[_startOfDay(day)] ?? 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final goal = context.watch<ConfigService>().recommendedDailyCount;
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      appBar: AppBar(title: Text(strings.calendarTitle)),
      body: FutureBuilder<Map<DateTime, int>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final history = snapshot.data ?? const <DateTime, int>{};
          final selectedCount = _countFor(history, _selectedDay);
          final selectedStatus = goalStatusFor(selectedCount, goal);

          return SafeArea(
            child: Column(
              children: [
                TableCalendar<int>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  locale: localeTag,
                  selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = _startOfDay(selected);
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) =>
                      setState(() => _focusedDay = focused),
                  calendarBuilders: CalendarBuilders<int>(
                    defaultBuilder: (context, day, _) => _DayCell(
                      day: day,
                      status: goalStatusFor(_countFor(history, day), goal),
                    ),
                    todayBuilder: (context, day, _) => _DayCell(
                      day: day,
                      status: goalStatusFor(_countFor(history, day), goal),
                      isToday: true,
                    ),
                    selectedBuilder: (context, day, _) => _DayCell(
                      day: day,
                      status: goalStatusFor(_countFor(history, day), goal),
                      isSelected: true,
                    ),
                    outsideBuilder: (context, day, _) => _DayCell(
                      day: day,
                      status: GoalStatus.none,
                      isOutside: true,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _Legend(strings: strings),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _SelectedDayCard(
                      day: _selectedDay,
                      count: selectedCount,
                      goal: goal,
                      status: selectedStatus,
                      localeTag: localeTag,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.status,
    this.isToday = false,
    this.isSelected = false,
    this.isOutside = false,
  });

  final DateTime day;
  final GoalStatus status;
  final bool isToday;
  final bool isSelected;
  final bool isOutside;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = colorForStatus(status);
    final hasFill = fill != Colors.transparent;
    final textColor = isOutside
        ? theme.disabledColor
        : hasFill
            ? Colors.white
            : theme.textTheme.bodyMedium?.color;

    final border = isSelected
        ? Border.all(color: theme.colorScheme.primary, width: 2)
        : isToday
            ? Border.all(color: theme.colorScheme.secondary, width: 1.5)
            : null;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          border: border,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendDot(
          color: colorForStatus(GoalStatus.reached),
          label: strings.legendGoalReached,
        ),
        _LegendDot(
          color: colorForStatus(GoalStatus.close),
          label: strings.legendGoalClose,
        ),
        _LegendDot(
          color: colorForStatus(GoalStatus.low),
          label: strings.legendGoalLow,
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.day,
    required this.count,
    required this.goal,
    required this.status,
    required this.localeTag,
  });

  final DateTime day;
  final int count;
  final int goal;
  final GoalStatus status;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateLabel = DateFormat.yMMMMd(localeTag).format(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: colorForStatus(status),
                shape: BoxShape.circle,
                border: status == GoalStatus.none
                    ? Border.all(color: theme.dividerColor)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              strings.progressLabel(count, goal),
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _statusLabel(strings, status),
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  String _statusLabel(AppLocalizations strings, GoalStatus status) {
    switch (status) {
      case GoalStatus.reached:
        return strings.statusGoalReached;
      case GoalStatus.close:
        return strings.statusGoalClose;
      case GoalStatus.low:
        return strings.statusGoalLow;
      case GoalStatus.none:
        return strings.statusGoalNone;
    }
  }
}
