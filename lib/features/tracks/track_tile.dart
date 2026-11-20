import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../library/library_provider.dart';
import '../player/player_provider.dart';

Future<void> likeTrack(BuildContext context, Track t) async {
  try {
    await context.read<LibraryProvider>().toggleFavorite(t);
  } catch (e) {
    if (context.mounted) toast(context, ApiError.from(e).message);
  }
}

Future<void> showAddToPlaylist(BuildContext context, Track t) async {
  final lib = context.read<LibraryProvider>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Consumer<LibraryProvider>(
        builder: (_, l, __) => ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text('افزودن به پلی‌لیست', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('پلی‌لیست جدید'),
              onTap: () async {
                Navigator.pop(sheet);
                final r = await askPlaylistInfo(context);
                if (r == null) return;
                try {
                  final p = await lib.createPlaylist(r.$1, r.$2);
                  await lib.addToPlaylist(p.id, t);
                  if (context.mounted) toast(context, 'به «${r.$1}» اضافه شد');
                } catch (e) {
                  if (context.mounted) toast(context, ApiError.from(e).message);
                }
              },
            ),
            for (final p in l.playlists)
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(p.name),
                subtitle: Text('${p.trackCount} آهنگ'),
                onTap: () async {
                  Navigator.pop(sheet);
                  try {
                    await lib.addToPlaylist(p.id, t);
                    if (context.mounted) toast(context, 'به «${p.name}» اضافه شد');
                  } catch (e) {
                    if (context.mounted) toast(context, ApiError.from(e).message);
                  }
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Returns (name, description) or null.
Future<(String, String)?> askPlaylistInfo(BuildContext context, {String name = '', String description = ''}) {
  final n = TextEditingController(text: name);
  final d = TextEditingController(text: description);
  return showDialog<(String, String)>(
    context: context,
    builder: (ctx) {
      String? err;
      return StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(name.isEmpty ? 'پلی‌لیست جدید' : 'ویرایش پلی‌لیست'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: n, autofocus: true, decoration: InputDecoration(labelText: 'نام', errorText: err)),
            const SizedBox(height: 8),
            TextField(controller: d, decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                if (n.text.trim().isEmpty) {
                  setS(() => err = 'نام را وارد کنید');
                  return;
                }
                Navigator.pop(ctx, (n.text.trim(), d.text.trim()));
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      );
    },
  );
}

class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.track, required this.onTap, this.onRemove});
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final fav = context.select<LibraryProvider, bool>((l) => l.isFav(track));
    final isCurrent = context.select<PlayerProvider, bool>((p) => p.current?.id == track.id);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Cover(track.coverUrl, size: 52),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, color: isCurrent ? kAccent : null)),
      subtitle: Text(
        [track.artist, if (track.album.isNotEmpty) track.album].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (track.duration > 0)
          Text(fmtDur(Duration(seconds: track.duration)), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        IconButton(
          tooltip: 'علاقه‌مندی',
          icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? Colors.redAccent : Colors.white54),
          onPressed: () => likeTrack(context, track),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
          onSelected: (v) {
            if (v == 'add') showAddToPlaylist(context, track);
            if (v == 'remove') onRemove?.call();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'add', child: Text('افزودن به پلی‌لیست')),
            if (onRemove != null) const PopupMenuItem(value: 'remove', child: Text('حذف از این پلی‌لیست')),
          ],
        ),
      ]),
    );
  }
}
