import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/diagnostics_store.dart';
import '../data/gateways.dart';
import '../domain/acoustic.dart';
import 'tap_service.dart';

/// What a listening session is for. The mode decides whether detections are
/// written to the log at all.
enum ListenMode {
  /// Design A — the mic informs the *suggested* quick tag on a manual tap and
  /// writes nothing. A wrong suggestion costs a shrug; a wrongly written event
  /// would corrupt the log.
  assist,

  /// Design B — Listen mode. Detections are logged as heard events.
  session,

  /// Design C — a live duel round. Logged, and also broadcast by DuelService.
  duel,
}

enum ListenState { idle, permissionDenied, starting, listening, error }

/// Owns the microphone and the detection cascade (live-detection-design.md §2).
///
/// Non-negotiables this class exists to honour:
///  * It is **never** in the tap path. `TapService.tap()` doesn't know it exists.
///  * It writes through [TapService.logHeard], so one place still owns event
///    creation and the heard/tapped split can't be bypassed.
///  * Every failure — permission, capture, model — is recorded to Diagnostics
///    rather than swallowed.
class ListenService extends ChangeNotifier {
  ListenService(
    this._capture,
    this._classifier,
    this._tap, {
    required bool Function() isPro,
    DiagnosticsRecorder? onError,
    DateTime Function()? clock,
    this.freeSessionBudget = const Duration(minutes: 5),
    this.threshold = kAcousticThreshold,
    this.refractory = kAcousticRefractory,
  })  : _isPro = isPro,
        _onError = onError,
        _clock = clock ?? DateTime.now;

  final AudioCaptureGateway _capture;
  final AcousticClassifier _classifier;
  final TapService _tap;
  final bool Function() _isPro;
  final DiagnosticsRecorder? _onError;
  final DateTime Function() _clock;

  /// How long a free-tier session may run before the paywall moment. Pro is
  /// unlimited. Never blocks the tap loop either way.
  final Duration freeSessionBudget;
  final double threshold;
  final Duration refractory;

  final _ring = _RingBuffer(kAcousticWindowSamples);
  final _detector = OnsetDetector();
  final List<AcousticDetection> _detections = [];

  StreamSubscription<Int16List>? _sub;
  ListenState _state = ListenState.idle;
  ListenMode _mode = ListenMode.session;
  DateTime? _startedAt;
  DateTime? _lastDetectionAt;
  double _level = 0;
  bool _classifying = false;
  bool _budgetExhausted = false;

  ListenState get state => _state;
  ListenMode get mode => _mode;
  bool get isListening => _state == ListenState.listening;

  /// 0..1, for the level meter.
  double get level => _level;

  List<AcousticDetection> get detections => List.unmodifiable(_detections);
  int get sessionCount => _detections.length;

  /// True when a free session ran out — the cue to open the paywall.
  bool get budgetExhausted => _budgetExhausted;

  Duration get elapsed {
    final started = _startedAt;
    return started == null ? Duration.zero : _clock().difference(started);
  }

  /// Time left in a free session; null when unlimited (Pro).
  Duration? get remaining {
    if (_isPro()) return null;
    final left = freeSessionBudget - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Design A: the most recent detection within [window], or null. Read by the
  /// quick-tag row to mark a suggested chip — it never writes.
  AcousticDetection? recentDetection({
    Duration window = const Duration(seconds: 5),
  }) {
    if (_detections.isEmpty) return null;
    final last = _detections.last;
    return _clock().difference(last.at) <= window ? last : null;
  }

  Future<void> start({ListenMode mode = ListenMode.session}) async {
    if (_state == ListenState.listening || _state == ListenState.starting) {
      return;
    }
    _mode = mode;
    _state = ListenState.starting;
    _budgetExhausted = false;
    notifyListeners();

    try {
      if (!await _capture.hasPermission() &&
          !await _capture.requestPermission()) {
        _state = ListenState.permissionDenied;
        notifyListeners();
        return;
      }

      await _classifier.load();

      _detections.clear();
      _ring.clear();
      _detector.reset();
      _lastDetectionAt = null;
      _startedAt = _clock();
      _sub = _capture.start().listen(
            _onFrame,
            onError: (Object e, StackTrace s) => _fail('listen.capture', e, s),
            onDone: stop,
          );
      _state = ListenState.listening;
    } catch (e, stack) {
      _fail('listen.start', e, stack);
      return;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    if (_sub == null && _state == ListenState.idle) return;
    // Note: cancel() completes on an event-loop turn, not a microtask, so
    // stopping is never synchronous. Tests must advance time, not just drain
    // microtasks, to observe the mic being released.
    await _sub?.cancel();
    _sub = null;
    try {
      await _capture.stop();
    } catch (e, stack) {
      // Already stopping; record it but don't strand the UI in a live state.
      _onError?.call('listen.stop', e, stack);
    }
    _level = 0;
    if (_state != ListenState.error &&
        _state != ListenState.permissionDenied) {
      _state = ListenState.idle;
    }
    notifyListeners();
  }

  /// Dismisses a false positive: deletes the event and drops it from the list.
  Future<void> undo(String id) async {
    _detections.removeWhere((d) => d.id == id);
    notifyListeners();
    await _tap.undoHeard(id);
  }

  Future<void> _onFrame(Int16List frame) async {
    _ring.write(frame);

    final rms = frameRms(frame);
    _level = rms.clamp(0.0, 1.0);

    // Free-tier budget. Checked on the frame stream so it ends promptly even
    // if nothing is being detected.
    final left = remaining;
    if (left != null && left == Duration.zero) {
      _budgetExhausted = true;
      await stop();
      return;
    }

    final onset = _detector.accept(rms);
    notifyListeners();
    if (!onset || _classifying || !_ring.isFull) return;

    // Refractory: two detections closer than this are one event heard twice.
    final last = _lastDetectionAt;
    if (last != null && _clock().difference(last) < refractory) return;

    _classifying = true;
    try {
      final verdict = await _classifier.classify(_ring.window());
      if (verdict.confidence >= threshold) await _accept(verdict);
    } catch (e, stack) {
      // A classification failure must not end the session — the user would
      // rather keep listening than be dumped out of the screen.
      _onError?.call('listen.classify', e, stack);
    } finally {
      _classifying = false;
    }
  }

  Future<void> _accept(AcousticVerdict verdict) async {
    final at = _clock();
    _lastDetectionAt = at;

    // Assist mode informs the tag suggestion and writes nothing.
    if (_mode == ListenMode.assist) {
      _detections.add(AcousticDetection(
        id: '',
        at: at,
        confidence: verdict.confidence,
        signature: verdict.signature,
      ));
      notifyListeners();
      return;
    }

    final tag = suggestedTag(verdict.signature);
    final id = await _tap.logHeard(tags: tag == null ? const [] : [tag]);
    _detections.add(AcousticDetection(
      id: id,
      at: at,
      confidence: verdict.confidence,
      signature: verdict.signature,
    ));
    notifyListeners();
  }

  void _fail(String source, Object error, StackTrace stack) {
    _onError?.call(source, error, stack);
    _state = ListenState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _classifier.dispose();
    super.dispose();
  }
}

/// Fixed-size sample ring. Always hands back the *most recent*
/// [kAcousticWindowSamples], which is why the classifier sees the attack of a
/// sound rather than starting after the gate noticed it.
class _RingBuffer {
  _RingBuffer(this.capacity) : _data = Float32List(capacity);

  final int capacity;
  final Float32List _data;
  int _write = 0;
  int _filled = 0;

  bool get isFull => _filled >= capacity;

  void clear() {
    _write = 0;
    _filled = 0;
  }

  void write(Int16List frame) {
    for (final sample in frame) {
      _data[_write] = sample / 32768.0;
      _write = (_write + 1) % capacity;
      if (_filled < capacity) _filled++;
    }
  }

  /// The last [capacity] samples in chronological order.
  Float32List window() {
    final out = Float32List(capacity);
    for (var i = 0; i < capacity; i++) {
      out[i] = _data[(_write + i) % capacity];
    }
    return out;
  }
}
