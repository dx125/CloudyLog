import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../branding/gust.dart';
import '../../theme/puff_theme.dart';

/// The product: a 158 px circle on a 10 px pillow. Press → button sinks,
/// heavy haptic, Gust puffs +8%, a small cloud drifts up and fades, and the
/// counter (outside) rolls. ~450 ms total.
///
/// Haptics and animation fire on the raw gesture (tap-down), before any
/// persistence — perceived latency is the product. Reduced motion keeps only
/// a color pulse; the haptic always fires.
class TapButton extends StatefulWidget {
  const TapButton({
    super.key,
    required this.onLog,
    required this.semanticsLabel,
    this.playSound = false,
    this.size = 158,
  });

  /// Called on tap-down — the log must register immediately.
  final VoidCallback onLog;
  final String semanticsLabel;
  final bool playSound;
  final double size;

  @override
  State<TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<TapButton> with TickerProviderStateMixin {
  static const double _pillowOffset = 10;

  late final AnimationController _puff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _cloud = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _puff.dispose();
    _cloud.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    // The raw gesture handler: haptic + feedback first, everything else after.
    HapticFeedback.heavyImpact();
    if (widget.playSound) SystemSound.play(SystemSoundType.click);
    setState(() => _pressed = true);
    if (!MediaQuery.of(context).disableAnimations) {
      _puff.forward(from: 0);
      _cloud.forward(from: 0);
    }
    widget.onLog();
  }

  void _release() {
    if (mounted) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final puff = context.puff;
    final reduced = MediaQuery.of(context).disableAnimations;
    final size = widget.size;

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: SizedBox(
          width: size + 26,
          height: size + _pillowOffset + 26,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // Dashed orbit ring.
              Positioned(
                top: 2,
                child: CustomPaint(
                  size: Size(size + 22, size + 22),
                  painter: _DashedRingPainter(
                    color: puff.barIdle.withValues(alpha: 0.7),
                  ),
                ),
              ),
              // The solid pillow the button sinks onto.
              Positioned(
                top: 13 + _pillowOffset,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: puff.pillow,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // The button itself.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                top: 13 + (_pressed ? _pillowOffset - 2 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    // Reduced motion: the color pulse is the remaining cue.
                    color: reduced && _pressed ? puff.pillow : puff.action,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _puff,
                      builder: (context, child) {
                        // Puff up 8%, then settle.
                        final t = _puff.value;
                        final scale =
                            1 + 0.08 * math.sin(t * math.pi).clamp(0.0, 1.0);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Gust(
                        body: puff.raised,
                        face: puff.pillow,
                        size: size * 0.62,
                      ),
                    ),
                  ),
                ),
              ),
              // A small cloud drifts up and fades.
              if (!reduced)
                AnimatedBuilder(
                  animation: _cloud,
                  builder: (context, _) {
                    final t = _cloud.value;
                    if (t == 0 || _cloud.isDismissed) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      top: 8 - 46 * t,
                      child: Opacity(
                        opacity: (1 - t) * 0.8,
                        child: _CloudPuff(color: puff.barIdle),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudPuff extends StatelessWidget {
  const _CloudPuff({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(34, 20), painter: _CloudPainter(color));
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(const Offset(9, 13), 7, paint);
    canvas.drawCircle(const Offset(18, 9), 9, paint);
    canvas.drawCircle(const Offset(27, 13), 7, paint);
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.color != color;
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const dashes = 36;
    const gapFraction = 0.5;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * (1 - gapFraction),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => old.color != color;
}
