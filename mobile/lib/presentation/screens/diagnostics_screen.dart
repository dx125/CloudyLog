import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../branding/gust.dart';
import '../../data/diagnostics_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/diagnostics_service.dart';
import '../../services/share_service.dart';
import '../../theme/puff_theme.dart';

/// Settings → Diagnostics: every error the app survived, newest first, with
/// stack traces. Copy puts the full retained log on the clipboard; Share
/// hands the on-disk files to the share sheet, so even a huge log exports
/// without being loaded into memory.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    final text = await context.read<DiagnosticsService>().fullText();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _snack(context, strings.diagnosticsCopied);
  }

  Future<void> _share(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    final diagnostics = context.read<DiagnosticsService>();
    final share = context.read<ShareService>();
    final paths = await diagnostics.exportFilePaths();
    if (paths.isNotEmpty) {
      await share.shareFiles(paths, text: strings.diagnosticsShareText);
    } else {
      // Store isn't file-backed (or writes failed): fall back to text —
      // still bounded by the retention cap.
      await share.shareText(await diagnostics.fullText());
    }
  }

  Future<void> _clear(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    await context.read<DiagnosticsService>().clear();
    if (context.mounted) _snack(context, strings.diagnosticsCleared);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;
    final diagnostics = context.watch<DiagnosticsService>();
    final entries = diagnostics.entries.reversed.toList();
    final hasEntries = diagnostics.totalCount > 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: strings.closeButton,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    strings.diagnosticsTitle,
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: Text(
                strings.diagnosticsIntro,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: hasEntries ? () => _copy(context) : null,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: Text(strings.copyButton),
                  ),
                  OutlinedButton.icon(
                    onPressed: hasEntries ? () => _share(context) : null,
                    icon: const Icon(Icons.ios_share_outlined, size: 18),
                    label: Text(strings.shareButton),
                  ),
                  TextButton(
                    onPressed: hasEntries ? () => _clear(context) : null,
                    child: Text(strings.clearButton),
                  ),
                ],
              ),
            ),
            if (hasEntries)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Text(
                  diagnostics.totalCount > entries.length
                      ? strings.diagnosticsCountTruncated(
                          diagnostics.totalCount,
                          entries.length,
                        )
                      : strings.diagnosticsCount(diagnostics.totalCount),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Gust(body: puff.action, face: puff.surface, size: 72),
                          const SizedBox(height: 14),
                          Text(
                            strings.diagnosticsEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                      itemCount: entries.length,
                      itemBuilder: (context, index) =>
                          _EntryTile(entry: entries[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatefulWidget {
  const _EntryTile({required this.entry});

  final DiagnosticsEntry entry;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final puff = context.puff;
    final entry = widget.entry;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final time =
        DateFormat.yMMMd(localeTag).add_Hms().format(entry.time.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(PuffRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: puff.surface,
            borderRadius: BorderRadius.circular(PuffRadius.lg),
            border: Border.all(color: puff.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$time · ${entry.source}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                entry.message,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              if (_expanded && entry.stack.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  entry.stack,
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
