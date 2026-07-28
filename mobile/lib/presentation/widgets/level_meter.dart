import 'package:flutter/material.dart';

import '../../theme/puff_theme.dart';

/// A row of bars showing the current input level.
///
/// Kept honest deliberately: it reflects the raw microphone level, not the
/// detector's opinion. When Puff misses something the user can see that it
/// *heard* it, which makes a miss read as a miss rather than a dead mic.
///
/// No drop shadows (design book): the idle track is a surface step and lit bars
/// are solid [PuffColors.action].
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.level, this.bars = 16});

  /// 0..1.
  final double level;
  final int bars;

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    // Perceptual-ish curve: a linear RMS meter sits near zero almost always.
    final shaped = level.clamp(0.0, 1.0);
    final lit = (shaped * bars).round();

    return SizedBox(
      height: 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < bars; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                height: 8 + (i <= lit ? 18 * (i / bars) : 0),
                decoration: BoxDecoration(
                  color: i <= lit ? puff.action : puff.hairline,
                  borderRadius: BorderRadius.circular(PuffRadius.pill),
                ),
              ),
            ),
            if (i != bars - 1) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}
