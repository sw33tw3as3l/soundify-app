import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';

enum LoadState { idle, loading, ready, empty, error }

class TracksProvider extends ChangeNotifier {
  TracksProvider(this.api);
  final ApiClient api;

  LoadState state = LoadState.idle;
  String? error;
  List<Track> featured = [];
  List<Track> all = [];
  int _page = 1;
  bool hasMore = false;
  bool loadingMore = false;
  String ordering = '-created_at';

  List<Track> _parse(Map<String, dynamic> m) => ((m['results'] as List?) ?? const [])
      .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  Future<void> load() async {
    state = LoadState.loading;
    error = null;
    notifyListeners();
    try {
      final f = await api.getMap('/tracks/featured', q: {'page_size': 20});
      final a = await api.getMap('/tracks', q: {'page': 1, 'page_size': 20, 'ordering': ordering});
      featured = _parse(f);
      all = _parse(a);
      _page = 1;
      hasMore = a['next'] != null;
      state = (all.isEmpty && featured.isEmpty) ? LoadState.empty : LoadState.ready;
    } catch (e) {
      error = ApiError.from(e).message;
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> setOrdering(String o) async {
    ordering = o;
    await load();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final a = await api.getMap('/tracks', q: {'page': _page + 1, 'page_size': 20, 'ordering': ordering});
      _page++;
      all = [...all, ..._parse(a)];
      hasMore = a['next'] != null;
    } catch (_) {
      hasMore = false;
    }
    loadingMore = false;
    notifyListeners();
  }

  void clear() {
    featured = [];
    all = [];
    state = LoadState.idle;
    notifyListeners();
  }

  /// Live search by title or artist (two queries, merged, no duplicates).
  Future<List<Track>> search(String q) async {
    final results = await Future.wait([
      api.getMap('/tracks', q: {'q': q, 'page_size': 30}),
      api.getMap('/tracks', q: {'artist': q, 'page_size': 30}).catchError((_) => <String, dynamic>{}),
    ]);
    final seen = <String>{};
    final out = <Track>[];
    for (final m in results) {
      for (final t in _parse(m)) {
        if (seen.add(t.id)) out.add(t);
      }
    }
    return out;
  }
}
