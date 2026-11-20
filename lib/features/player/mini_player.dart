import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import 'full_player.dart';
import 'player_provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final t = p.current;
    if (t == null) return const SizedBox.shrink();
    return Material(
      color: kSurface,
      child: InkWell(
        onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => const FullPlayerScreen(),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        )),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          StreamBuilder<Duration>(
            stream: p.player.positionStream,
            builder: (_, s) {
              final total = (p.player.duration ?? Duration(seconds: t.duration)).inMilliseconds;
              final v = total > 0 ? ((s.data?.inMilliseconds ?? 0) / total).clamp(0.0, 1.0) : 0.0;
              return LinearProgressIndicator(value: v, minHeight: 2, backgroundColor: Colors.white10);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Cover(t.coverUrl, size: 44, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ),
              IconButton(onPressed: p.previous, icon: const Icon(Icons.skip_previous_rounded)),
              p.buffering
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
                  : IconButton(
                      onPressed: p.toggle,
                      icon: Icon(p.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 38, color: kAccent),
                    ),
              IconButton(onPressed: p.next, icon: const Icon(Icons.skip_next_rounded)),
            ]),
          ),
        ]),
      ),
    );
  }
}
