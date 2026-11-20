import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_screens.dart';
import '../player/player_provider.dart';
import '../tracks/track_tile.dart';
import '../tracks/tracks_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (_sc.position.pixels > _sc.position.maxScrollExtent - 400) context.read<TracksProvider>().loadMore();
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  static const _orders = [('-created_at', 'جدیدترین'), ('title', 'نام'), ('-duration', 'طولانی‌ترین'), ('duration', 'کوتاه‌ترین')];

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TracksProvider>();
    final name = context.select<AuthProvider, String>((a) => a.user?.shownName ?? '');
    return SafeArea(
      child: StateView(
        state: tp.state,
        error: tp.error,
        onRetry: tp.load,
        emptyText: 'هنوز آهنگی موجود نیست.',
        builder: (_) => RefreshIndicator(
          onRefresh: tp.load,
          child: CustomScrollView(
            controller: _sc,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SecurityBanner(),
                    Text(name.isEmpty ? 'سلام 👋' : 'سلام، $name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('امروز چی گوش می‌دی؟', style: TextStyle(color: Colors.white60)),
                  ]),
                ),
              ),
              if (tp.featured.isNotEmpty) ...[
                const SliverToBoxAdapter(child: _Title('منتخب‌ها')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 196,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: tp.featured.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final t = tp.featured[i];
                        return GestureDetector(
                          onTap: () => context.read<PlayerProvider>().playQueue(tp.featured, i),
                          child: SizedBox(
                            width: 140,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Cover(t.coverUrl, size: 140, radius: 14),
                              const SizedBox(height: 8),
                              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: _Title('همه آهنگ‌ها')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final o in _orders)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(label: Text(o.$2), selected: tp.ordering == o.$1, onSelected: (_) => tp.setOrdering(o.$1)),
                        ),
                    ],
                  ),
                ),
              ),
              if (tp.all.isEmpty)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('آهنگی پیدا نشد.', style: TextStyle(color: Colors.white54)))))
              else
                SliverList.builder(
                  itemCount: tp.all.length,
                  itemBuilder: (_, i) => TrackTile(track: tp.all[i], onTap: () => context.read<PlayerProvider>().playQueue(tp.all, i)),
                ),
              SliverToBoxAdapter(
                child: tp.loadingMore
                    ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                    : const SizedBox(height: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );
}
