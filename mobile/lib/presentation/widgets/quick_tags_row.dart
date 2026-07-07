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
    this.onAddCustom,
    this.addLabel,
  });

  final List<TagOption> tags;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

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
              onTap: enabled ? () => onToggle(tag.id) : null,
              puff: puff,
              style: labelStyle,
            ),
          if (onAddCustom != null)
            _chip(
              context,
              label: addLabel ?? '+',
              selected: false,
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
    required VoidCallback? onTap,
    required PuffColors puff,
    required TextStyle style,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? puff.chipSelectedBg : puff.surface,
          borderRadius: BorderRadius.circular(PuffRadius.pill),
          border: Border.all(
            color: selected ? puff.chipSelectedBorder : puff.hairline,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: style.copyWith(
            color: selected ? puff.chipSelectedBorder : puff.textSecondary,
          ),
        ),
      ),
    );
  }
}
