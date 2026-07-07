import 'package:flutter/material.dart';

import '../../theme/puff_theme.dart';

/// Puff's primary button: fully-round pill sitting on a solid color "pillow".
/// No shadows anywhere — depth is the hard offset, and pressing sinks the
/// pill onto it.
class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.pillowColor,
    this.foregroundColor,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? color;
  final Color? pillowColor;
  final Color? foregroundColor;
  final bool enabled;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  static const double _offset = 5;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    final color = widget.color ?? puff.action;
    final pillow = widget.pillowColor ?? puff.pillow;
    final foreground = widget.foregroundColor ?? puff.onAction;
    final textStyle = Theme.of(context)
        .textTheme
        .labelLarge!
        .copyWith(color: foreground);

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(PuffRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: foreground),
            const SizedBox(width: 10),
          ],
          Text(widget.label, style: textStyle),
        ],
      ),
    );

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed();
              }
            : null,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _offset),
              child: Container(
                decoration: BoxDecoration(
                  color: pillow,
                  borderRadius: BorderRadius.circular(PuffRadius.pill),
                ),
                child: Opacity(opacity: 0, child: pill),
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 80),
              padding: EdgeInsets.only(
                top: _pressed ? _offset - 1 : 0,
                bottom: _pressed ? 1 : _offset,
              ),
              child: pill,
            ),
          ],
        ),
      ),
    );
  }
}
