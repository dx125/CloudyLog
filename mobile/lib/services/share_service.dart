import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

abstract class ShareService {
  Future<void> shareText(String text);
  Future<void> shareImage(Uint8List pngBytes, {required String text});
}

class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareText(String text) async {
    await Share.share(text);
  }

  @override
  Future<void> shareImage(Uint8List pngBytes, {required String text}) async {
    await Share.shareXFiles(
      [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'puff.png')],
      text: text,
    );
  }
}

/// Captures the RepaintBoundary under [key] as PNG bytes at 3x for
/// story-quality share cards.
Future<Uint8List?> capturePng(GlobalKey key) async {
  final object = key.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;
  final image = await object.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
