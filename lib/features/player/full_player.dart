import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../library/library_provider.dart';
import '../tracks/track_tile.dart';
import 'player_provider.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final t = p.current;
    if (t == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold();
    }
    final fav = context.select<LibraryProvider, bool>((l) => l.isFav(t));
    final width = MediaQuery.sizeOf(context).width;
    final cover = math.min(width - 64, 340.0);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32), onPressed: () => Navigator.pop(context)),
        title: const Text('در حال پخش', style: TextStyle(fontSize: 15)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.playlist_add_rounded), tooltip: 'افزودن به پلی‌لیست', onPressed: () => showAddToPlaylist(context, t)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const Spacer(),
            Container(
              decoration: BoxDecoration(boxShadow: [BoxShadow(color: kAccent.withValues(alpha: 0.18), blurRadius: 40, spreadRadius: 2)]),
              child: Cover(t.coverUrl, size: cover, radius: 20),
            ),
            const SizedBox(height: 24),
            Equalizer(active: p.playing && !p.buffering),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text([t.artist, if (t.album.isNotEmpty) t.album].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
                ]),
              ),
              IconButton(
                iconSize: 30,
                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? Colors.redAccent : Colors.white70),
                onPressed: () => likeTrack(context, t),
              ),
            ]),
            const SizedBox(height: 8),
            _Seek(p: p, fallback: Duration(seconds: t.duration)),
            const SizedBox(height: 4),
            if (p.error != null) Text(p.error!, style: const TextStyle(color: Colors.redAccent)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(iconSize: 44, onPressed: p.previous, icon: const Icon(Icons.skip_previous_rounded)),
              const SizedBox(width: 12),
              p.buffering
                  ? const SizedBox(width: 72, height: 72, child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 3)))
                  : IconButton(
                      iconSize: 72,
                      color: kAccent,
                      onPressed: p.toggle,
                      icon: Icon(p.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                    ),
              const SizedBox(width: 12),
              IconButton(iconSize: 44, onPressed: p.next, icon: const Icon(Icons.skip_next_rounded)),
            ]),
            const Spacer(),
          ]),
        ),
      ),
    );
  }
}

class _Seek extends StatefulWidget {
  const _Seek({required this.p, required this.fallback});
  final PlayerProvider p;
  final Duration fallback;
  @override
  State<_Seek> createState() => _SeekState();
}

class _SeekState extends State<_Seek> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final player = widget.p.player;
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (_, ds) {
        final total = ds.data ?? widget.fallback;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (_, ps) {
            final pos = ps.data ?? Duration.zero;
            final max = math.max(total.inMilliseconds.toDouble(), 1.0);
            final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max);
            return Column(children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Slider(
                  value: value,
                  max: max,
                  onChanged: (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    player.seek(Duration(milliseconds: v.round()));
                    setState(() => _drag = null);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(fmtDur(Duration(milliseconds: value.round())), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    Text(fmtDur(total), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ]),
                ),
              ),
            ]);
          },
        );
      },
    );
  }
}

/// Animated bars; they settle to a flat line when playback is paused.
class Equalizer extends StatefulWidget {
  const Equalizer({super.key, required this.active});
  final bool active;
  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(Equalizer old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 24; i++)
              Container(
                width: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: widget.active
                    ? 5 + 27 * (0.5 + 0.5 * math.sin(_c.value * 2 * math.pi * (1 + (i % 3)) + i * 0.7)).abs()
                    : 4,
                decoration: BoxDecoration(color: kAccent.withValues(alpha: widget.active ? 0.9 : 0.35), borderRadius: BorderRadius.circular(3)),
              ),
          ],
        ),
      ),
    );
  }
}
