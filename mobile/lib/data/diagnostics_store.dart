import 'dart:convert';

/// Signature catch sites use to report a survived error into diagnostics —
/// the offline-first fallbacks are deliberate, but they must never be
/// invisible (Settings → Diagnostics shows everything recorded).
typedef DiagnosticsRecorder = void Function(
  String source,
  Object error,
  StackTrace stack,
);

/// One captured failure. [stack] may be empty when the throw site had none.
class DiagnosticsEntry {
  const DiagnosticsEntry({
    required this.time,
    required this.source,
    required this.message,
    this.stack = '',
  });

  final DateTime time;

  /// Where it was caught, e.g. 'sync.push' or 'flutter'.
  final String source;
  final String message;
  final String stack;

  String toJsonLine() => jsonEncode({
        't': time.toIso8601String(),
        's': source,
        'm': message,
        'st': stack,
      });

  /// Null for lines that aren't valid entries (corruption, partial writes).
  static DiagnosticsEntry? fromJsonLine(String line) {
    try {
      final map = jsonDecode(line) as Map<String, dynamic>;
      return DiagnosticsEntry(
        time: DateTime.parse(map['t'] as String),
        source: (map['s'] as String?) ?? '',
        message: (map['m'] as String?) ?? '',
        stack: (map['st'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Human-readable block for the clipboard export.
  String format() {
    final buffer = StringBuffer('[${time.toIso8601String()}] $source\n$message');
    if (stack.isNotEmpty) buffer.write('\n$stack');
    return buffer.toString();
  }
}

/// Append-only error log with bounded retention: however long the app has
/// been failing, the whole log stays small enough to put on a clipboard, and
/// file-backed implementations can hand their files to the share sheet
/// without ever loading them into memory.
abstract class DiagnosticsStore {
  Future<void> append(DiagnosticsEntry entry);

  /// The newest [limit] entries, oldest first.
  Future<List<DiagnosticsEntry>> tail(int limit);

  Future<int> totalCount();

  /// Every retained entry rendered with [DiagnosticsEntry.format].
  Future<String> fullText();

  /// On-disk log files (oldest first) for zero-copy sharing; empty when
  /// nothing is stored or the store isn't file-backed.
  Future<List<String>> exportFilePaths();

  Future<void> clear();
}
