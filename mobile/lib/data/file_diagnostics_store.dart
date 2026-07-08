import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diagnostics_store.dart';

/// JSONL log under the app-support directory with one-step rotation:
/// `puff-diagnostics.log` (current) plus `puff-diagnostics.1.log` (previous
/// generation). Retention is bounded at ~2 × [maxBytes], so "copy the whole
/// log" stays a clipboard-sized string no matter how noisy the app gets,
/// while sharing hands the files over as-is. Every method swallows its own
/// IO errors — a diagnostics log that crashes the app would be peak irony.
class FileDiagnosticsStore implements DiagnosticsStore {
  FileDiagnosticsStore({
    Future<Directory> Function()? directory,
    this.maxBytes = 512 * 1024,
  }) : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  final int maxBytes;

  Future<(File, File)> _files() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return (
      File(p.join(dir.path, 'puff-diagnostics.log')),
      File(p.join(dir.path, 'puff-diagnostics.1.log')),
    );
  }

  @override
  Future<void> append(DiagnosticsEntry entry) async {
    try {
      final (current, previous) = await _files();
      if (await current.exists() && await current.length() >= maxBytes) {
        if (await previous.exists()) await previous.delete();
        await current.rename(previous.path);
      }
      // After a rotation `current.path` points at nothing; append recreates it.
      await current.writeAsString(
        '${entry.toJsonLine()}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  Future<List<String>> _allLines() async {
    try {
      final (current, previous) = await _files();
      final lines = <String>[];
      for (final file in [previous, current]) {
        if (await file.exists()) {
          lines.addAll(const LineSplitter().convert(await file.readAsString()));
        }
      }
      return lines;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<DiagnosticsEntry>> tail(int limit) async {
    final lines = await _allLines();
    final entries = <DiagnosticsEntry>[];
    for (var i = lines.length - 1; i >= 0 && entries.length < limit; i--) {
      final entry = DiagnosticsEntry.fromJsonLine(lines[i]);
      if (entry != null) entries.add(entry);
    }
    return entries.reversed.toList();
  }

  @override
  Future<int> totalCount() async => (await _allLines()).length;

  @override
  Future<String> fullText() async {
    final lines = await _allLines();
    return [
      for (final line in lines) DiagnosticsEntry.fromJsonLine(line)?.format(),
    ].whereType<String>().join('\n\n');
  }

  @override
  Future<List<String>> exportFilePaths() async {
    try {
      final (current, previous) = await _files();
      return [
        if (await previous.exists()) previous.path,
        if (await current.exists()) current.path,
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> clear() async {
    try {
      final (current, previous) = await _files();
      if (await previous.exists()) await previous.delete();
      if (await current.exists()) await current.delete();
    } catch (_) {}
  }
}
