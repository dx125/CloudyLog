import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class CloudingProgressBar extends StatelessWidget {
  const CloudingProgressBar({
    super.key,
    required this.current,
    required this.goal,
  });

  final int current;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final safeGoal = goal <= 0 ? 1 : goal;

    final ratio = current / safeGoal;
    final clampedRatio = ratio.clamp(0.0, 1.0).toDouble();
    final overflowRatio = (ratio - 1.0).clamp(0.0, 1.0).toDouble();
    final reached = current >= goal && goal > 0;

    final percent = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.progressLabel(current, goal),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              strings.progressPercentLabel(percent),
              style: theme.textTheme.titleMedium?.copyWith(
                color: reached ? theme.colorScheme.primary : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: clampedRatio,
                minHeight: 16,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  reached
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                ),
              ),
            ),
            if (overflowRatio > 0)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: constraints.maxWidth * overflowRatio,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (reached)
          Text(
            current > goal
                ? strings.goalExceeded(current - goal)
                : strings.goalReached,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
