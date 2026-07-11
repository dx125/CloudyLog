// Renders the Puff brand assets (app icon + splash logos) straight from the
// Gust mascot geometry, using Flutter's own engine — no external rasterizer.
//
// Run:  flutter test tool/render_brand_assets.dart
//
// It writes PNG sources into assets/branding/, which flutter_launcher_icons and
// flutter_native_splash then turn into the native Android resources. Gust is the
// canonical "one ellipse + three circles" from lib/branding/gust.dart; the icon
// is the design book's App Store icon (bright mint body on ink, Design Book §02).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Palette (Design Book §03).
const _mintBright = Color(0xFF5DCAA5);
const _deepTeal = Color(0xFF0F6E56);
const _ink = Color(0xFF1E2A38);
const _inkDeep = Color(0xFF141D28);
const _cloud = Color(0xFFF4FAF6);

/// Paints Gust in its native 140x100 coordinate space, scaled and centered so
/// its content box fills [widthFraction] of a [size]-square canvas.
void _paintGust(
  Canvas canvas,
  double size, {
  required Color body,
  required Color face,
  required bool gustLines,
  required double widthFraction,
  bool punchFace = false,
}) {
  // Content bounding box in native coords (tighter without the gust lines).
  final minX = gustLines ? 8.0 : 28.0;
  final maxX = gustLines ? 132.0 : 110.0;
  const minY = 20.0;
  const maxY = 85.0;
  final contentW = maxX - minX;
  final cx = (minX + maxX) / 2;
  const cy = (minY + maxY) / 2;

  final scale = size * widthFraction / contentW;
  canvas.save();
  canvas.translate(size / 2, size / 2);
  canvas.scale(scale);
  canvas.translate(-cx, -cy);

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

  // Plain dot eyes in the surface color — or punched to transparent holes for
  // the monochrome themed icon, so the tinted body reads as Gust's face.
  final facePaint = punchFace
      ? (Paint()..blendMode = BlendMode.clear)
      : (Paint()..color = face);
  canvas.drawCircle(const Offset(58, 58), 4.5, facePaint);
  canvas.drawCircle(const Offset(82, 58), 4.5, facePaint);

  // A single rounded smile stroke.
  final smile = Paint()
    ..color = face
    ..blendMode = punchFace ? BlendMode.clear : BlendMode.srcOver
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    Path()
      ..moveTo(62, 70)
      ..quadraticBezierTo(70, 77, 78, 70),
    smile,
  );

  if (gustLines) {
    final gust = Paint()
      ..color = body.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(8, 82)
        ..quadraticBezierTo(20, 76, 30, 82),
      gust,
    );
    canvas.drawPath(
      Path()
        ..moveTo(110, 82)
        ..quadraticBezierTo(122, 76, 132, 82),
      gust,
    );
  }
  canvas.restore();
}

Future<void> _writePng(
  String path,
  int size, {
  Color? background,
  required Color body,
  required Color face,
  required bool gustLines,
  required double widthFraction,
  bool punchFace = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final full = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  if (background != null) {
    canvas.drawRect(full, Paint()..color = background);
  }
  // Punching holes needs a layer so BlendMode.clear erases within it to
  // transparent rather than compositing against the (empty) canvas root.
  if (punchFace) canvas.saveLayer(full, Paint());
  _paintGust(
    canvas,
    size.toDouble(),
    body: body,
    face: face,
    gustLines: gustLines,
    widthFraction: widthFraction,
    punchFace: punchFace,
  );
  if (punchFace) canvas.restore();
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $path (${bytes.lengthInBytes} bytes)');
}

void main() {
  test('render Puff brand assets', () async {
    const dir = 'assets/branding';

    // Full app icon — the design book's App Store icon: bright mint Gust on
    // ink, gust lines on. Legacy launcher + flutter_launcher_icons source.
    await _writePng(
      '$dir/icon.png',
      1024,
      background: _ink,
      body: _mintBright,
      face: _ink,
      gustLines: true,
      widthFraction: 0.80,
    );

    // Adaptive icon foreground — transparent, body only (no gust lines) so it
    // sits comfortably inside the circular mask's safe zone. Face is the ink
    // adaptive background so the eyes/smile read as cut-outs. Sized so that,
    // after the launcher's 16% inset, Gust still fills the icon with presence.
    await _writePng(
      '$dir/icon_foreground.png',
      1024,
      body: _mintBright,
      face: _ink,
      gustLines: false,
      widthFraction: 0.70,
    );

    // Monochrome layer for Android 13+ themed icons. Body is opaque white and
    // the face is punched out; the launcher tints the silhouette to the user's
    // wallpaper palette, so Gust's face still reads.
    await _writePng(
      '$dir/icon_monochrome.png',
      1024,
      body: const Color(0xFFFFFFFF),
      face: const Color(0xFFFFFFFF),
      gustLines: false,
      widthFraction: 0.70,
      punchFace: true,
    );

    // Splash logos, transparent, centered on the native splash color.
    // Light: deep-teal Gust on cloud.
    await _writePng(
      '$dir/splash.png',
      1152,
      body: _deepTeal,
      face: _cloud,
      gustLines: true,
      widthFraction: 0.60,
    );
    // Dark: bright-mint Gust on ink-deep.
    await _writePng(
      '$dir/splash_dark.png',
      1152,
      body: _mintBright,
      face: _inkDeep,
      gustLines: true,
      widthFraction: 0.60,
    );

    expect(File('$dir/icon.png').existsSync(), isTrue);
    expect(File('$dir/icon_foreground.png').existsSync(), isTrue);
    expect(File('$dir/icon_monochrome.png').existsSync(), isTrue);
    expect(File('$dir/splash.png').existsSync(), isTrue);
    expect(File('$dir/splash_dark.png').existsSync(), isTrue);
  });
}
