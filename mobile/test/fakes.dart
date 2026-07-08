import 'package:puff/data/diagnostics_store.dart';
import 'package:puff/data/event_store.dart';
import 'package:puff/data/gateways.dart';
import 'package:puff/data/settings_repository.dart';
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
    events[id] = PuffEvent(
      id: existing.id,
      occurredAt: existing.occurredAt,
      type: existing.type,
      tags: tags,
      deviceId: existing.deviceId,
    );
  }

  @override
  Future<PuffEvent?> byId(String id) async => events[id];

  @override
  Future<int> countForDay(DateTime day) async {
    final target = dayOf(day);
    return events.values
        .where((e) => e.type == kTootType && dayOf(e.occurredAt) == target)
        .length;
  }

  @override
  Future<List<PuffEvent>> eventsBetween(DateTime from, DateTime to) async {
    final list = events.values
        .where((e) =>
            !e.occurredAt.isBefore(from) && e.occurredAt.isBefore(to))
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  @override
  Future<List<PuffEvent>> allEvents() async {
    final list = events.values.toList()
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
  Future<Map<DateTime, int>> countsByDay() async {
    final counts = <DateTime, int>{};
    for (final event in events.values) {
      if (event.type != kTootType) continue;
      final day = dayOf(event.occurredAt);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  String theme = 'system';
  bool sound = false;
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
