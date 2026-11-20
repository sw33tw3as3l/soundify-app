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
      notifyListeners();
    });
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      error = 'پخش این آهنگ ممکن نشد. اتصال را بررسی کنید.';
      notifyListeners();
    });
  }

  final AudioPlayer player = AudioPlayer();
  List<Track> queue = [];
  Track? current;
  bool playing = false;
  bool buffering = false;
  String? error;

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

  Future<void> playQueue(List<Track> tracks, int index) async {
    if (tracks.isEmpty) return;
    queue = List.of(tracks);
    current = queue[index];
    error = null;
    notifyListeners();
    try {
      await player.setAudioSources(queue.map(_source).toList(), initialIndex: index, initialPosition: Duration.zero);
      player.play();
    } catch (e) {
      error = 'پخش این آهنگ ممکن نشد. اتصال را بررسی کنید.';
      notifyListeners();
    }
  }

  void toggle() => playing ? player.pause() : player.play();

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
