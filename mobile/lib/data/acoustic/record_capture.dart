import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../domain/acoustic.dart';
import '../gateways.dart';

/// Microphone capture via the `record` plugin.
///
/// The configuration here is the load-bearing part, and it is deliberately the
/// opposite of what a voice app would choose. Every platform speech-DSP feature
/// is **off**:
///
///  * [RecordConfig.autoGain] — automatic gain control normalises loudness,
///    which is the single most useful feature for telling a thunder from a
///    squeak. With AGC on, every sound arrives the same size.
///  * [RecordConfig.noiseSuppress] — tuned to keep speech and discard the rest.
///    To that algorithm a toot *is* the noise, so it attenuates precisely what
///    we're listening for.
///  * [RecordConfig.echoCancel] — adaptive filtering that alters the spectrum
///    differently on every handset, destroying train/serve consistency.
///
/// The training corpus must be captured with these same settings. A model
/// trained on a different signal chain than it runs on is the classic silent
/// failure in this kind of feature: it works on the dev's phone and quietly
/// degrades everywhere else.
class RecordAudioCapture implements AudioCaptureGateway {
  RecordAudioCapture({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _sub;
  StreamController<Int16List>? _out;

  static const _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: kAcousticSampleRate,
    numChannels: 1,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
  );

  @override
  Future<bool> hasPermission() => _recorder.hasPermission(request: false);

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Stream<Int16List> start() {
    final out = StreamController<Int16List>(onCancel: stop);
    _out = out;

    () async {
      try {
        final raw = await _recorder.startStream(_config);
        _sub = raw.listen(
          (bytes) {
            if (!out.isClosed) out.add(_toPcm16(bytes));
          },
          onError: out.addError,
          onDone: out.close,
        );
      } catch (e, stack) {
        // Surfaces through ListenService → DiagnosticsService rather than
        // stranding the stream open and silent.
        if (!out.isClosed) {
          out.addError(e, stack);
          await out.close();
        }
      }
    }();

    return out.stream;
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.cancel();
    } finally {
      final out = _out;
      _out = null;
      if (out != null && !out.isClosed) await out.close();
    }
  }

  /// Reinterprets the platform's little-endian byte stream as PCM16 samples.
  ///
  /// Uses a copy rather than a zero-copy view: the plugin may reuse its buffer,
  /// and the ring buffer downstream reads frames asynchronously.
  static Int16List _toPcm16(Uint8List bytes) {
    final samples = Int16List(bytes.length ~/ 2);
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little);
    }
    return samples;
  }
}
