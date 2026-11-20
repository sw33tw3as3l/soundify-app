import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../player/mini_player.dart';
import '../player/player_provider.dart';
import '../tracks/track_tile.dart';
import '../tracks/tracks_provider.dart';
import 'library_provider.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(alignment: AlignmentDirectional.centerStart, child: Text('کتابخانه', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          ),
          const TabBar(tabs: [Tab(text: 'پلی‌لیست‌ها'), Tab(text: 'علاقه‌مندی‌ها')]),
          Expanded(
            child: StateView(
              state: lib.state,
              error: lib.error,
              onRetry: lib.load,
              builder: (_) => TabBarView(children: [_Playlists(lib: lib), _Favorites(lib: lib)]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Favorites extends StatelessWidget {
  const _Favorites({required this.lib});
  final LibraryProvider lib;
  @override
  Widget build(BuildContext context) {
    if (lib.favorites.isEmpty) {
      return const StateView(state: LoadState.empty, onRetry: _noop, builder: _noBuilder, emptyText: 'هنوز آهنگی لایک نکرده‌اید.', emptyIcon: Icons.favorite_border_rounded);
    }
    return RefreshIndicator(
      onRefresh: lib.load,
      child: ListView.builder(
        itemCount: lib.favorites.length,
        itemBuilder: (_, i) => TrackTile(track: lib.favorites[i], onTap: () => context.read<PlayerProvider>().playQueue(lib.favorites, i)),
      ),
    );
  }
}

void _noop() {}
Widget _noBuilder(BuildContext c) => const SizedBox.shrink();

class _Playlists extends StatelessWidget {
  const _Playlists({required this.lib});
  final LibraryProvider lib;

  Future<void> _create(BuildContext context) async {
    final r = await askPlaylistInfo(context);
    if (r == null) return;
    try {
      await lib.createPlaylist(r.$1, r.$2);
    } catch (e) {
      if (context.mounted) toast(context, ApiError.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      lib.playlists.isEmpty
          ? const StateView(state: LoadState.empty, onRetry: _noop, builder: _noBuilder, emptyText: 'هنوز پلی‌لیستی نساخته‌اید.', emptyIcon: Icons.queue_music_rounded)
          : RefreshIndicator(
              onRefresh: lib.load,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: lib.playlists.length,
                itemBuilder: (_, i) {
                  final p = lib.playlists[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.queue_music_rounded, color: kAccent),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${p.trackCount} آهنگ${p.description.isEmpty ? '' : ' · ${p.description}'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PlaylistDetailScreen(playlistId: p.id))),
                  );
                },
              ),
            ),
      PositionedDirectional(
        end: 16,
        bottom: 16,
        child: FloatingActionButton.extended(onPressed: () => _create(context), icon: const Icon(Icons.add_rounded), label: const Text('پلی‌لیست جدید')),
      ),
    ]);
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final int playlistId;
  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  LoadState _state = LoadState.loading;
  String _err = '';
  List<Track> _tracks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = LoadState.loading);
    try {
      final t = await context.read<LibraryProvider>().playlistTracks(widget.playlistId);
      if (!mounted) return;
      setState(() {
        _tracks = t;
        _state = t.isEmpty ? LoadState.empty : LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = ApiError.from(e).message;
        _state = LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    Playlist? p;
    for (final x in lib.playlists) {
      if (x.id == widget.playlistId) p = x;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.name ?? 'پلی‌لیست'),
        actions: [
          if (p != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final pl = p!;
                if (v == 'edit') {
                  final r = await askPlaylistInfo(context, name: pl.name, description: pl.description);
                  if (r == null) return;
                  try {
                    await lib.updatePlaylist(pl.id, r.$1, r.$2);
                  } catch (e) {
                    if (context.mounted) toast(context, ApiError.from(e).message);
                  }
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف پلی‌لیست'),
                      content: Text('«${pl.name}» حذف شود؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await lib.deletePlaylist(pl.id);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) toast(context, ApiError.from(e).message);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('ویرایش نام و توضیحات')),
                PopupMenuItem(value: 'delete', child: Text('حذف پلی‌لیست')),
              ],
            ),
        ],
      ),
      body: StateView(
        state: _state,
        error: _err,
        onRetry: _load,
        emptyText: 'این پلی‌لیست خالی است. از منوی هر آهنگ آن را اضافه کنید.',
        emptyIcon: Icons.queue_music_rounded,
        builder: (_) => ListView(children: [
          if (p != null && p.description.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text(p.description, style: const TextStyle(color: Colors.white60))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: FilledButton.icon(
              onPressed: () => context.read<PlayerProvider>().playQueue(_tracks, 0),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('پخش همه'),
            ),
          ),
          for (var i = 0; i < _tracks.length; i++)
            TrackTile(
              track: _tracks[i],
              onTap: () => context.read<PlayerProvider>().playQueue(_tracks, i),
              onRemove: () async {
                try {
                  await lib.removeFromPlaylist(widget.playlistId, _tracks[i].id);
                  await _load();
                } catch (e) {
                  if (context.mounted) toast(context, ApiError.from(e).message);
                }
              },
            ),
        ]),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
