import 'package:flutter/material.dart';

/// Gust, the Puff mascot: a small cloud of air with a face.
///
/// Construction rules (Design Book §02): always one ellipse and three circles
/// — never more lumps, never fewer. Eyes are plain dots in the background
/// color, the smile is a single rounded stroke, and two short double-gust
/// lines may float beside the body. No gradients, outlines or shadows.
class Gust extends StatelessWidget {
  const Gust({
    super.key,
    required this.body,
    required this.face,
    this.gustLines = false,
    this.size = 96,
  });

  /// Deep teal on light surfaces, bright mint on dark surfaces.
  final Color body;

  /// Eyes and smile — the color of the surface Gust sits on.
  final Color face;
  final bool gustLines;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 100 / 140),
      painter: _GustPainter(body: body, face: face, gustLines: gustLines),
    );
  }
}

class _GustPainter extends CustomPainter {
  const _GustPainter({
    required this.body,
    required this.face,
    required this.gustLines,
  });

  final Color body;
  final Color face;
  final bool gustLines;

  @override
  void paint(Canvas canvas, Size size) {
    // Native coordinate space is 140 x 100 (the design book's tap-button SVG).
    final s = size.width / 140;
    canvas.scale(s, s);

    final bodyPaint = Paint()..color = body;
    // One ellipse...
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(70, 62), width: 72, height: 46),
      bodyPaint,
    );
    // ...and three circles. Never more lumps, never fewer.
    canvas.drawCircle(const Offset(45, 50), 17, bodyPaint);
    canvas.drawCircle(const Offset(70, 41), 21, bodyPaint);
    canvas.drawCircle(const Offset(95, 52), 15, bodyPaint);

    // Plain dot eyes in the background color.
    final facePaint = Paint()..color = face;
    canvas.drawCircle(const Offset(58, 58), 4.5, facePaint);
    canvas.drawCircle(const Offset(82, 58), 4.5, facePaint);

    // A single rounded smile stroke.
    final smile = Paint()
      ..color = face
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(62, 70)
      ..quadraticBezierTo(70, 77, 78, 70);
    canvas.drawPath(smilePath, smile);

    if (gustLines) {
      final gust = Paint()
        ..color = body.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final left = Path()
        ..moveTo(8, 82)
        ..quadraticBezierTo(20, 76, 30, 82);
      final right = Path()
        ..moveTo(110, 82)
        ..quadraticBezierTo(122, 76, 132, 82);
      canvas.drawPath(left, gust);
      canvas.drawPath(right, gust);
    }
  }

  @override
  bool shouldRepaint(_GustPainter old) =>
      old.body != body || old.face != face || old.gustLines != gustLines;
}

/// Gust bobbing gently on a 4.5 s float loop — home screen only. Honors
/// reduced-motion (bobbing off, Gust still shown).
class FloatingGust extends StatefulWidget {
  const FloatingGust({super.key, required this.child});

  final Widget child;

  @override
  State<FloatingGust> createState() => _FloatingGustState();
}

class _FloatingGustState extends State<FloatingGust>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          -5 * Curves.easeInOut.transform(_controller.value),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
