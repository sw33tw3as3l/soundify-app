import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../tracks/tracks_provider.dart';

class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this.api);
  final ApiClient api;

  LoadState state = LoadState.idle;
  String? error;
  List<Track> favorites = [];
  Set<String> favIds = {};
  List<Playlist> playlists = [];
  bool favoritesLoaded = false;

  bool isFav(Track t) => favoritesLoaded ? favIds.contains(t.id) : t.isFavorite;

  Future<void> load() async {
    state = LoadState.loading;
    error = null;
    notifyListeners();
    try {
      final f = await api.getAll('/favorites');
      final p = await api.getAll('/playlists');
      favorites = f.map(Track.fromJson).toList();
      favIds = favorites.map((t) => t.id).toSet();
      favoritesLoaded = true;
      playlists = p.map(Playlist.fromJson).toList();
      state = LoadState.ready;
    } catch (e) {
      error = ApiError.from(e).message;
      state = LoadState.error;
    }
    notifyListeners();
  }

  void clear() {
    favorites = [];
    favIds = {};
    playlists = [];
    favoritesLoaded = false;
    state = LoadState.idle;
    notifyListeners();
  }

  /// Optimistic like/unlike, reverted if the server refuses.
  Future<void> toggleFavorite(Track t) async {
    final was = isFav(t);
    if (was) {
      favIds.remove(t.id);
      favorites.removeWhere((x) => x.id == t.id);
    } else {
      favIds.add(t.id);
      favorites.insert(0, t);
    }
    favoritesLoaded = true;
    notifyListeners();
    try {
      if (was) {
        await api.delete('/favorites/${t.id}');
      } else {
        await api.postMap('/favorites', {'track_id': t.id});
      }
    } catch (e) {
      final err = ApiError.from(e);
      final harmless = (!was && err.status == 409) || (was && err.status == 404);
      if (!harmless) {
        if (was) {
          favIds.add(t.id);
          favorites.insert(0, t);
        } else {
          favIds.remove(t.id);
          favorites.removeWhere((x) => x.id == t.id);
        }
        notifyListeners();
        throw err;
      }
    }
  }

  Future<Playlist> createPlaylist(String name, String description) async {
    final m = await api.postMap('/playlists', {'name': name.trim(), 'description': description.trim(), 'is_public': false});
    await _reloadPlaylists();
    return playlists.firstWhere((p) => p.id == (m['id'] as num?)?.toInt(),
        orElse: () => playlists.isNotEmpty ? playlists.first : Playlist.fromJson({'id': 0}));
  }

  Future<void> updatePlaylist(int id, String name, String description) async {
    await api.patchMap('/playlists/$id', {'name': name.trim(), 'description': description.trim()});
    await _reloadPlaylists();
  }

  Future<void> deletePlaylist(int id) async {
    await api.delete('/playlists/$id');
    playlists.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> addToPlaylist(int id, Track t) async {
    await api.postMap('/playlists/$id/tracks', {'track_id': t.id});
    await _reloadPlaylists();
  }

  Future<void> removeFromPlaylist(int id, String trackId) async {
    await api.delete('/playlists/$id/tracks/$trackId');
    await _reloadPlaylists();
  }

  Future<List<Track>> playlistTracks(int id) async {
    final m = await api.getMap('/playlists/$id');
    return ((m['tracks'] as List?) ?? const [])
        .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _reloadPlaylists() async {
    final p = await api.getAll('/playlists');
    playlists = p.map(Playlist.fromJson).toList();
    notifyListeners();
  }
}
