import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../branding/gust.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/share_service.dart';
import '../../theme/puff_theme.dart';

/// A square, mascot-branded share card sized for stories and chats. Cards are
/// always rendered on the light mint world so they look identical everywhere.
class PuffShareCard extends StatelessWidget {
  const PuffShareCard({
    super.key,
    required this.headline,
    required this.lines,
  });

  final String headline;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: PuffPalette.mint,
        borderRadius: BorderRadius.circular(PuffRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gust(
            body: PuffPalette.deepTeal,
            face: PuffPalette.mint,
            gustLines: true,
            size: 92,
          ),
          const Spacer(),
          Text(
            headline,
            style: GoogleFonts.baloo2(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: PuffPalette.deepTeal,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Text(
              line,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PuffPalette.ink,
              ),
            ),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context)!.shareCardFooter,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PuffPalette.teal,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview-then-share dialog: the visible RepaintBoundary is what gets
/// captured, so what you see is exactly what you share.
Future<void> showShareCardDialog(
  BuildContext context, {
  required String headline,
  required List<String> lines,
  required String shareText,
}) async {
  final boundaryKey = GlobalKey();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final strings = AppLocalizations.of(dialogContext)!;
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: boundaryKey,
              child: PuffShareCard(headline: headline, lines: lines),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    strings.closeButton,
                    style: const TextStyle(color: PuffPalette.mintSoft),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: PuffPalette.teal,
                  ),
                  onPressed: () async {
                    final share = dialogContext.read<ShareService>();
                    final bytes = await capturePng(boundaryKey);
                    if (bytes == null) {
                      await share.shareText(shareText);
                    } else {
                      await share.shareImage(bytes, text: shareText);
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: Text(strings.shareButton),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
