import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

// ═══════════════════════════════════════════════════════════════
//  SoundService — generates WAV tones at runtime, no asset files
//  needed. All sounds are pre-built once at construction time.
//
//  Usage:
//    SoundService.instance.playCorrect();
//    SoundService.instance.playWrong();
//    SoundService.instance.playTick();
//    SoundService.instance.playTimeout();
//    SoundService.instance.playBuzz();
//    SoundService.instance.playWin();
//    SoundService.instance.playLose();
// ═══════════════════════════════════════════════════════════════
class SoundService {
  SoundService._() {
    _correct = _build([(659.25, 0.10, 0.65), (880.00, 0.22, 0.70)]);
    _wrong   = _build([(160.00, 0.15, 0.80), (130.81, 0.30, 0.75)]);
    _tick    = _build([(880.00, 0.07, 0.40)]);
    _timeout = _build([(440.00, 0.18, 0.60), (329.63, 0.30, 0.60)]);
    _buzz    = _build([(220.00, 0.13, 0.85)]);
    _win     = _build([
      (523.25, 0.12, 0.65),
      (659.25, 0.12, 0.65),
      (783.99, 0.12, 0.65),
      (1046.5, 0.28, 0.80),
    ]);
    _lose    = _build([
      (523.25, 0.18, 0.60),
      (466.16, 0.18, 0.60),
      (415.30, 0.18, 0.60),
      (261.63, 0.36, 0.70),
    ]);
  }

  static final SoundService instance = SoundService._();

  late final Uint8List _correct;
  late final Uint8List _wrong;
  late final Uint8List _tick;
  late final Uint8List _timeout;
  late final Uint8List _buzz;
  late final Uint8List _win;
  late final Uint8List _lose;

  // Pool of players so sounds can overlap (e.g. tick while animation runs)
  final List<AudioPlayer> _pool = [];

  AudioPlayer _nextPlayer() {
    for (final p in _pool) {
      if (p.state == PlayerState.stopped ||
          p.state == PlayerState.completed) {
        return p;
      }
    }
    final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _pool.add(p);
    return p;
  }

  Future<void> _play(Uint8List wav) async {
    try {
      await _nextPlayer().play(BytesSource(wav));
    } catch (_) {}
  }

  Future<void> playCorrect() => _play(_correct);
  Future<void> playWrong()   => _play(_wrong);
  Future<void> playTick()    => _play(_tick);
  Future<void> playTimeout() => _play(_timeout);
  Future<void> playBuzz()    => _play(_buzz);
  Future<void> playWin()     => _play(_win);
  Future<void> playLose()    => _play(_lose);

  void dispose() {
    for (final p in _pool) {
      p.dispose();
    }
    _pool.clear();
  }

  // ── WAV generation ────────────────────────────────────────────
  static const int _sr = 22050; // sample rate

  // Build a WAV from a list of (frequency Hz, duration sec, volume 0-1).
  // Notes are concatenated in order — no gap between them.
  Uint8List _build(List<(double, double, double)> notes) {
    final samples = <int>[];
    for (final (freq, dur, vol) in notes) {
      final n = (dur * _sr).round();
      final att = max(1, (_sr * 0.005).round()); // 5 ms attack
      final rel = max(1, (_sr * 0.08).round());  // 80 ms release
      for (var i = 0; i < n; i++) {
        double env = 1.0;
        if (i < att) {
          env = i / att;
        } else if (i > n - rel) {
          env = (n - i) / rel;
        }
        final v = (sin(2 * pi * freq * i / _sr) * vol * env * 32767)
            .round()
            .clamp(-32768, 32767);
        samples.add(v);
      }
    }
    return _toWav(samples);
  }

  Uint8List _toWav(List<int> samples) {
    final pcmData = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      pcmData.setInt16(i * 2, samples[i], Endian.little);
    }
    final pcm = pcmData.buffer.asUint8List();

    final hdr = ByteData(44);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        hdr.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    hdr.setUint32(4, 36 + pcm.length, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    hdr.setUint32(16, 16, Endian.little); // chunk size
    hdr.setUint16(20, 1, Endian.little);  // PCM format
    hdr.setUint16(22, 1, Endian.little);  // mono
    hdr.setUint32(24, _sr, Endian.little);
    hdr.setUint32(28, _sr * 2, Endian.little); // byte rate
    hdr.setUint16(32, 2, Endian.little);  // block align
    hdr.setUint16(34, 16, Endian.little); // bits per sample
    str(36, 'data');
    hdr.setUint32(40, pcm.length, Endian.little);

    return Uint8List.fromList([...hdr.buffer.asUint8List(), ...pcm]);
  }
}
