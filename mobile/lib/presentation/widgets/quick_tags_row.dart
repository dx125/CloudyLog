import 'package:flutter/material.dart';

import '../../theme/puff_theme.dart';

class TagOption {
  const TagOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// The quick-tag chip row. Chips only act on the last log and only for 10
/// seconds after a tap ([enabled]); outside the window they fade.
class QuickTagsRow extends StatelessWidget {
  const QuickTagsRow({
    super.key,
    required this.tags,
    required this.selected,
    required this.enabled,
    required this.onToggle,
    this.suggested,
    this.onAddCustom,
    this.addLabel,
  });

  final List<TagOption> tags;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

  /// Design A: the tag the microphone thinks it heard. Marked with a dashed
  /// outline, **never auto-applied** — the user still taps it.
  ///
  /// A wrong suggestion costs a shrug. A wrongly *written* tag would put a
  /// guess into the health log, which is the one thing this feature must not
  /// do, so the mic stays out of the write path entirely.
  final String? suggested;

  /// Pro: lets the user define their own tag. Null hides the chip.
  final VoidCallback? onAddCustom;
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    final labelStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final tag in tags)
            _chip(
              context,
              label: tag.label,
              selected: selected.contains(tag.id),
              // Only hint while the window is open and the chip isn't already
              // chosen — a suggestion on a selected chip is just noise.
              hinted: enabled &&
                  tag.id == suggested &&
                  !selected.contains(tag.id),
              onTap: enabled ? () => onToggle(tag.id) : null,
              puff: puff,
              style: labelStyle,
            ),
          if (onAddCustom != null)
            _chip(
              context,
              label: addLabel ?? '+',
              selected: false,
              hinted: false,
              onTap: onAddCustom,
              puff: puff,
              style: labelStyle,
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required bool hinted,
    required VoidCallback? onTap,
    required PuffColors puff,
    required TextStyle style,
  }) {
    // The hint uses `action`, never `pro`: coral is rationed to one use per
    // screen (Pro markers, streaks, celebrations) and a tag guess hasn't
    // earned it.
    final borderColor = selected
        ? puff.chipSelectedBorder
        : hinted
            ? puff.action
            : puff.hairline;
    final textColor = selected
        ? puff.chipSelectedBorder
        : hinted
            ? puff.action
            : puff.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.fromLTRB(hinted ? 9 : 12, 6, 12, 6),
        decoration: BoxDecoration(
          color: selected
              ? puff.chipSelectedBg
              : hinted
                  ? puff.action.withValues(alpha: 0.08)
                  : puff.surface,
          borderRadius: BorderRadius.circular(PuffRadius.pill),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hinted) ...[
              Icon(Icons.mic_none_rounded, size: 13, color: puff.action),
              const SizedBox(width: 3),
            ],
            Text(label, style: style.copyWith(color: textColor)),
          ],
        ),
      ),
    );
  }
}
