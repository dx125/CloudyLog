import 'package:flutter/material.dart';

import '../../theme/puff_theme.dart';

/// Seven slim bars, today highlighted. Charts never rely on color alone —
/// the hot bar is also the labeled, tallest-context element via semantics.
class WeekChart extends StatelessWidget {
  const WeekChart({
    super.key,
    required this.counts,
    this.hotIndex,
    this.height = 44,
  });

  /// Oldest first.
  final List<int> counts;

  /// Which bar gets the highlight color (defaults to the last one, today).
  final int? hotIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    final hot = hotIndex ?? counts.length - 1;
    final max = counts.fold(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < counts.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: Semantics(
                label: '${counts[i]}',
                child: Container(
                  height: max == 0
                      ? 4
                      : (4 + (height - 4) * counts[i] / max),
                  decoration: BoxDecoration(
                    color: i == hot ? puff.barHot : puff.barIdle,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                      bottom: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
