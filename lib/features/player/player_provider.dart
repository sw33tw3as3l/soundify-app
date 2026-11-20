import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../core/models.dart';

class PlayerProvider extends ChangeNotifier {
  PlayerProvider() {
    player.currentIndexStream.listen((i) {
      if (i != null && i >= 0 && i < queue.length && current?.id != queue[i].id) {
        current = queue[i];
        notifyListeners();
      }
    });
    player.playerStateStream.listen((s) {
      playing = s.playing;
      buffering = s.processingState == ProcessingState.loading || s.processingState == ProcessingState.buffering;
      if (s.processingState == ProcessingState.ready && error != null) error = null;
      notifyListeners();
    });
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) => _recoverCurrent());
    player.errorStream.listen((_) => _recoverCurrent());
    // Watchdog: a stream that stays loading for 20 s, or a player that went idle
    // after an error while the user still wants music, is retried / skipped.
    Timer.periodic(const Duration(seconds: 4), (_) {
      if (_recovering || current == null) return;
      final ps = player.processingState;
      if (ps == ProcessingState.loading || ps == ProcessingState.buffering) {
        _busySince ??= DateTime.now();
        if (DateTime.now().difference(_busySince!) > const Duration(seconds: 20)) {
          _busySince = null;
          _recoverCurrent();
        }
      } else {
        _busySince = null;
        if (ps == ProcessingState.idle && _wantPlay) _recoverCurrent();
      }
    });
  }

  DateTime? _busySince;
  bool _wantPlay = false;

  void _recoverCurrent() {
    final i = queue.indexWhere((t) => t.id == current?.id);
    if (i >= 0) _recoverFrom(i);
  }

  final AudioPlayer player = AudioPlayer();
  List<Track> queue = [];
  Track? current;
  bool playing = false;
  bool buffering = false;
  String? error;
  bool _recovering = false;

  bool get hasTrack => current != null;

  AudioSource _source(Track t) => AudioSource.uri(
        Uri.parse(t.streamUrl),
        tag: MediaItem(
          id: t.id,
          title: t.title,
          artist: t.artist,
          album: t.album,
          artUri: t.coverUrl.isNotEmpty ? Uri.parse(t.coverUrl) : null,
          duration: t.duration > 0 ? Duration(seconds: t.duration) : null,
        ),
      );

  /// Loads the queue at [index]; gives up after 12 s so a stalled stream
  /// never leaves the player stuck on "connecting".
  Future<bool> _load(int index) async {
    current = queue[index];
    notifyListeners();
    try {
      await player
          .setAudioSources(queue.map(_source).toList(), initialIndex: index, initialPosition: Duration.zero)
          .timeout(const Duration(seconds: 12));
      _wantPlay = true;
      player.play();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> playQueue(List<Track> tracks, int index) async {
    if (tracks.isEmpty) return;
    queue = List.of(tracks);
    error = null;
    if (!await _load(index)) await _recoverFrom(index);
  }

  /// A stream that fails is retried once, then the player moves on to the next
  /// tracks (at most 3) so one broken file never stops the playlist.
  Future<void> _recoverFrom(int index) async {
    if (_recovering) return;
    _recovering = true;
    try {
      error = 'اتصال ضعیف است؛ تلاش دوباره...';
      notifyListeners();
      if (await _load(index)) return;
      for (var i = index + 1; i < queue.length && i <= index + 3; i++) {
        error = 'آهنگ قبلی پخش نشد؛ آهنگ بعدی پخش می‌شود.';
        notifyListeners();
        if (await _load(i)) return;
      }
      error = 'پخش این آهنگ ممکن نشد. اتصال را بررسی کنید.';
      _wantPlay = false;
      notifyListeners();
    } finally {
      _recovering = false;
    }
  }

  void toggle() {
    if (playing) {
      _wantPlay = false;
      player.pause();
    } else {
      _wantPlay = true;
      if (player.processingState == ProcessingState.idle) {
        _recoverCurrent();
      } else {
        player.play();
      }
    }
  }

  Future<void> next() async {
    if (player.hasNext) await player.seekToNext();
  }

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3) || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> stop() async {
    _wantPlay = false;
    await player.stop();
    queue = [];
    current = null;
    playing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
