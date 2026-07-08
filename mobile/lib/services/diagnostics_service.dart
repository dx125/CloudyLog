import 'package:flutter/foundation.dart';

import '../data/diagnostics_store.dart';

/// Collects the errors the app deliberately survives — failed syncs, cloud
/// hiccups, framework exceptions — so "it degraded gracefully" never means
/// "the evidence is gone". Surfaced under Settings → Diagnostics with copy
/// and share-as-file export.
///
/// An in-memory ring (the newest [ringSize] entries, previous runs included)
/// backs the UI; the full bounded log lives in the [DiagnosticsStore].
/// [record] never throws and never blocks the caller.
class DiagnosticsService extends ChangeNotifier {
  DiagnosticsService(
    this._store, {
    DateTime Function()? clock,
    this.ringSize = 200,
    this.maxStackChars = 6000,
  }) : _clock = clock ?? DateTime.now;

  final DiagnosticsStore _store;
  final DateTime Function() _clock;
  final int ringSize;

  /// Stack traces are truncated to keep single entries from eating the
  /// bounded retention (a deep async chain can run tens of KB).
  final int maxStackChars;

  final List<DiagnosticsEntry> _recent = [];
  int _totalCount = 0;
  bool _recording = false;
  Future<void> _writes = Future.value();

  /// Newest last.
  List<DiagnosticsEntry> get entries => List.unmodifiable(_recent);
  int get totalCount => _totalCount;

  /// Loads persisted history, so errors from previous runs (including startup
  /// crashes) are visible too.
  Future<void> load() async {
    final tail = await _store.tail(ringSize);
    _recent
      ..clear()
      ..addAll(tail);
    _totalCount = await _store.totalCount();
    notifyListeners();
  }

  /// Matches [DiagnosticsRecorder]; persistence is queued fire-and-forget so
  /// a record from a hot path costs no await.
  void record(String source, Object error, [StackTrace? stack]) {
    if (_recording) return; // a throwing listener must not recurse into us
    _recording = true;
    try {
      var stackText = (stack ?? StackTrace.empty).toString().trimRight();
      if (stackText.length > maxStackChars) {
        stackText = stackText.substring(0, maxStackChars);
      }
      final entry = DiagnosticsEntry(
        time: _clock(),
        source: source,
        message: error.toString(),
        stack: stackText,
      );
      _recent.add(entry);
      if (_recent.length > ringSize) _recent.removeAt(0);
      _totalCount++;
      // Serialized appends: concurrent records never interleave file writes.
      _writes = _writes.then((_) => _store.append(entry));
      notifyListeners();
    } catch (_) {
      // Nothing sensible left to do with an error about logging errors.
    } finally {
      _recording = false;
    }
  }

  /// The whole retained log as text (clipboard export). Bounded by the
  /// store's retention cap, so safe to hold in memory.
  Future<String> fullText() async {
    await _writes;
    return _store.fullText();
  }

  /// On-disk log files for zero-copy sharing; empty when nothing is stored.
  Future<List<String>> exportFilePaths() async {
    await _writes;
    return _store.exportFilePaths();
  }

  Future<void> clear() async {
    await _writes;
    await _store.clear();
    _recent.clear();
    _totalCount = 0;
    notifyListeners();
  }
}
