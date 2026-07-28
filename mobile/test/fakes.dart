import 'dart:async';
import 'dart:typed_data';

import 'package:puff/data/diagnostics_store.dart';
import 'package:puff/data/event_store.dart';
import 'package:puff/data/gateways.dart';
import 'package:puff/data/settings_repository.dart';
import 'package:puff/domain/acoustic.dart';
import 'package:puff/domain/duel.dart';
import 'package:puff/domain/entitlement.dart';
import 'package:puff/domain/puff_event.dart';

class InMemoryEventStore implements EventStore {
  final Map<String, PuffEvent> events = {};

  @override
  Future<void> insert(PuffEvent event) async {
    events[event.id] = event;
  }

  @override
  Future<void> upsertAll(List<PuffEvent> incoming, {required bool synced}) async {
    for (final event in incoming) {
      events[event.id] =
          event.copyWith(syncedAt: synced ? DateTime.now() : null);
    }
  }

  @override
  Future<void> updateTags(String id, List<String> tags) async {
    final existing = events[id];
    if (existing == null) return;
    // copyWith leaves syncedAt null, which is the point: a tag edit must be
    // re-pushed. It also carries `source` through, so a heard event stays heard.
    events[id] = existing.copyWith(tags: tags);
  }

  @override
  Future<void> delete(String id) async {
    events.remove(id);
  }

  @override
  Future<PuffEvent?> byId(String id) async => events[id];

  @override
  Future<int> countForDay(
    DateTime day, {
    SourceFilter source = SourceFilter.tapped,
  }) async {
    final target = dayOf(day);
    return events.values
        .where((e) =>
            e.type == kTootType &&
            source.matches(e.source) &&
            dayOf(e.occurredAt) == target)
        .length;
  }

  @override
  Future<List<PuffEvent>> eventsBetween(
    DateTime from,
    DateTime to, {
    SourceFilter source = SourceFilter.all,
  }) async {
    final list = events.values
        .where((e) =>
            !e.occurredAt.isBefore(from) &&
            e.occurredAt.isBefore(to) &&
            source.matches(e.source))
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  @override
  Future<List<PuffEvent>> allEvents({
    SourceFilter source = SourceFilter.all,
  }) async {
    final list = events.values.where((e) => source.matches(e.source)).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  @override
  Future<List<PuffEvent>> unsynced(int limit) async {
    final list = events.values.where((e) => e.syncedAt == null).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list.take(limit).toList();
  }

  @override
  Future<void> markSynced(List<String> ids, DateTime at) async {
    for (final id in ids) {
      final event = events[id];
      if (event != null) events[id] = event.copyWith(syncedAt: at);
    }
  }

  @override
  Future<Map<DateTime, int>> countsByDay({
    SourceFilter source = SourceFilter.tapped,
  }) async {
    final counts = <DateTime, int>{};
    for (final event in events.values) {
      if (event.type != kTootType) continue;
      if (!source.matches(event.source)) continue;
      final day = dayOf(event.occurredAt);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  String theme = 'system';
  bool sound = false;
  bool listenAssist = false;
  List<String> tags = [];
  Entitlement? entitlement;
  String? lastReportDay;

  @override
  Future<String> deviceId() async => 'test-device';

  @override
  Future<String> themeMode() async => theme;

  @override
  Future<void> setThemeMode(String mode) async => theme = mode;

  @override
  Future<bool> soundEnabled() async => sound;

  @override
  Future<void> setSoundEnabled(bool value) async => sound = value;

  @override
  Future<bool> listenAssistEnabled() async => listenAssist;

  @override
  Future<void> setListenAssistEnabled(bool value) async => listenAssist = value;

  @override
  Future<List<String>> customTags() async => tags;

  @override
  Future<void> setCustomTags(List<String> value) async => tags = value;

  @override
  Future<Entitlement?> cachedEntitlement() async => entitlement;

  @override
  Future<void> cacheEntitlement(Entitlement? value) async =>
      entitlement = value;

  @override
  Future<String?> lastStatsReportDay() async => lastReportDay;

  @override
  Future<void> setLastStatsReportDay(String day) async =>
      lastReportDay = day;
}

class FakePurchaseGateway implements PurchaseGateway {
  Entitlement? remote;
  bool offline = false;
  DateTime Function() now = DateTime.now;

  void _checkOnline() {
    if (offline) throw const CloudUnavailable();
  }

  @override
  Future<Entitlement?> fetch() async {
    _checkOnline();
    return remote;
  }

  @override
  Future<Entitlement> purchasePro() async {
    _checkOnline();
    remote = Entitlement(
      status: 'active',
      expiresAt: now().add(const Duration(days: 30)),
    );
    return remote!;
  }

  @override
  Future<Entitlement> cancelPro() async {
    _checkOnline();
    final current = remote;
    if (current == null) throw const CloudUnavailable('no subscription');
    remote = Entitlement(status: 'canceled', expiresAt: current.expiresAt);
    return remote!;
  }
}

class FakeEventsSyncGateway implements EventsSyncGateway {
  final Map<String, PuffEvent> server = {};
  bool offline = false;
  int pushCalls = 0;

  @override
  Future<void> push(List<PuffEvent> events) async {
    if (offline) throw const CloudUnavailable();
    pushCalls++;
    for (final event in events) {
      server[event.id] = event;
    }
  }

  @override
  Future<List<PuffEvent>> pullAll() async {
    if (offline) throw const CloudUnavailable();
    return server.values.toList();
  }
}

class FakeGlobalStatsGateway implements GlobalStatsGateway {
  GlobalDailyStats? stats;
  bool offline = false;
  int latestCalls = 0;
  final List<List<DailyTootCount>> reports = [];

  @override
  Future<GlobalDailyStats?> latest() async {
    if (offline) throw const CloudUnavailable();
    latestCalls++;
    return stats;
  }

  @override
  Future<void> reportDaily(List<DailyTootCount> days) async {
    if (offline) throw const CloudUnavailable();
    reports.add(days);
  }
}

/// A scriptable microphone. Tests push frames by hand, so the whole detection
/// cascade is exercised without ever opening a real capture device.
class FakeAudioCaptureGateway implements AudioCaptureGateway {
  FakeAudioCaptureGateway({this.permitted = true});

  bool permitted;
  bool permissionAsked = false;
  bool started = false;
  bool stopped = false;

  final _controller = StreamController<Int16List>.broadcast();

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    permissionAsked = true;
    return permitted;
  }

  @override
  Stream<Int16List> start() {
    started = true;
    return _controller.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  /// Emits one frame at the given amplitude (0..1), then lets the listener
  /// chain run to completion.
  ///
  /// Drains the microtask queue with `await null` rather than
  /// `Future.delayed(Duration.zero)`: inside `testWidgets` a zero-duration
  /// delay is a *timer*, and timers only advance when the tester pumps — so a
  /// delay-based yield deadlocks in widget tests. Microtasks drain in both
  /// worlds. The loop covers the awaits between a frame arriving and an event
  /// being written: deliver → onFrame → classify → logHeard → store.insert.
  Future<void> emit(double amplitude, {int samples = 320}) async {
    final value = (amplitude * 32767).round().clamp(-32768, 32767);
    _controller.add(Int16List.fromList(List.filled(samples, value)));
    for (var i = 0; i < 8; i++) {
      await null;
    }
  }

  /// Emits [count] quiet frames — enough to settle the noise floor, or to fill
  /// the ring buffer before a burst.
  Future<void> emitQuiet(int count, {int samples = 320}) async {
    for (var i = 0; i < count; i++) {
      await emit(0.001, samples: samples);
    }
  }

  Future<void> close() => _controller.close();
}

/// Returns queued verdicts, so tests decide exactly what the "model" heard.
class FakeAcousticClassifier implements AcousticClassifier {
  FakeAcousticClassifier({this.failOnClassify = false});

  final List<AcousticVerdict> queued = [];
  bool loaded = false;
  bool disposed = false;
  int classifyCalls = 0;
  bool failOnClassify;

  /// Verdict returned once the queue is empty.
  AcousticVerdict fallback = AcousticVerdict.silence;

  void enqueue(double confidence, {AcousticSignature? signature}) {
    queued.add(AcousticVerdict(
      confidence: confidence,
      signature: signature ?? AcousticSignature.unknown,
    ));
  }

  @override
  Future<void> load() async => loaded = true;

  @override
  Future<AcousticVerdict> classify(Float32List window) async {
    classifyCalls++;
    if (failOnClassify) throw StateError('classifier exploded');
    return queued.isEmpty ? fallback : queued.removeAt(0);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeDuelGateway implements DuelGateway {
  final List<Duel> duels = [];
  final List<({String duelId, int tapped, int heard})> submissions = [];
  final List<String> joined = [];

  bool offline = false;
  bool proBlocked = false;
  bool atFreeLimit = false;
  String? unavailableReason;
  int listCalls = 0;
  int nextId = 1;

  void _checkOnline() {
    if (offline) throw const CloudUnavailable();
  }

  @override
  Future<List<Duel>> list() async {
    _checkOnline();
    listCalls++;
    return List.of(duels);
  }

  @override
  Future<Duel?> preview(String code) async {
    _checkOnline();
    for (final duel in duels) {
      if (duel.code == code) return duel;
    }
    return null;
  }

  @override
  Future<Duel> create({required DuelKind kind}) async {
    _checkOnline();
    // Mirrors the server: creating is Pro-gated by RLS, whose 403 arrives as
    // CloudUnavailable.
    if (proBlocked) throw const CloudUnavailable('403');
    final now = DateTime(2026, 7, 20, 12);
    final duel = Duel(
      id: 'duel-${nextId++}',
      code: 'CODE${nextId}A',
      kind: kind,
      nameAdjective: 0,
      nameNoun: 0,
      startsAt: now,
      endsAt: now.add(
        kind == DuelKind.live
            ? const Duration(minutes: 3)
            : const Duration(days: 7),
      ),
      status: DuelStatus.open,
    );
    duels.add(duel);
    return duel;
  }

  @override
  Future<void> join(String code) async {
    _checkOnline();
    if (atFreeLimit) throw const DuelLimitReached();
    final reason = unavailableReason;
    if (reason != null) throw DuelUnavailable(reason);
    joined.add(code);
  }

  @override
  Future<void> submitScore(String duelId, {int tapped = 0, int heard = 0}) async {
    _checkOnline();
    submissions.add((duelId: duelId, tapped: tapped, heard: heard));
  }

  @override
  Future<void> leave(String duelId) async {
    _checkOnline();
    duels.removeWhere((d) => d.id == duelId);
  }
}

class FakeDuelChannel implements DuelChannel {
  final List<({String duelId, int count})> published = [];
  String? joinedDuelId;
  bool left = false;

  final _controller = StreamController<DuelLiveScore>.broadcast();

  @override
  Stream<DuelLiveScore> join(String duelId) {
    joinedDuelId = duelId;
    return _controller.stream;
  }

  @override
  Future<void> publish(String duelId, int count) async {
    published.add((duelId: duelId, count: count));
  }

  @override
  Future<void> leave() async {
    left = true;
  }

  /// Simulates an opponent's broadcast arriving.
  void emitOpponent(String userId, int count) {
    _controller.add(DuelLiveScore(userId: userId, count: count));
  }

  Future<void> close() => _controller.close();
}

class InMemoryDiagnosticsStore implements DiagnosticsStore {
  final List<DiagnosticsEntry> entries = [];

  @override
  Future<void> append(DiagnosticsEntry entry) async => entries.add(entry);

  @override
  Future<List<DiagnosticsEntry>> tail(int limit) async =>
      entries.length <= limit
          ? List.of(entries)
          : entries.sublist(entries.length - limit);

  @override
  Future<int> totalCount() async => entries.length;

  @override
  Future<String> fullText() async =>
      [for (final e in entries) e.format()].join('\n\n');

  @override
  Future<List<String>> exportFilePaths() async => const [];

  @override
  Future<void> clear() async => entries.clear();
}
