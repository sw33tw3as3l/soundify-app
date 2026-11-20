import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../player/player_provider.dart';
import '../tracks/track_tile.dart';
import '../tracks/tracks_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  Timer? _debounce;
  LoadState _state = LoadState.idle;
  String _err = '';
  List<Track> _results = [];
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  /// Waits 450 ms after the last keystroke before calling the server.
  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _state = LoadState.idle;
        _results = [];
      });
      return;
    }
    setState(() => _state = LoadState.loading);
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(v.trim()));
  }

  Future<void> _run(String q) async {
    final my = ++_seq;
    try {
      final r = await context.read<TracksProvider>().search(q);
      if (!mounted || my != _seq) return;
      setState(() {
        _results = r;
        _state = r.isEmpty ? LoadState.empty : LoadState.ready;
      });
    } catch (e) {
      if (!mounted || my != _seq) return;
      setState(() {
        _err = ApiError.from(e).message;
        _state = LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _c,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'نام آهنگ یا خواننده',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _c.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _c.clear(); _onChanged(''); }),
            ),
          ),
        ),
        Expanded(
          child: _state == LoadState.idle
              ? const Center(child: Text('برای جست‌وجو تایپ کنید', style: TextStyle(color: Colors.white54)))
              : StateView(
                  state: _state,
                  error: _err,
                  emptyText: 'نتیجه‌ای پیدا نشد.',
                  emptyIcon: Icons.search_off_rounded,
                  onRetry: () => _run(_c.text.trim()),
                  builder: (_) => ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) => TrackTile(track: _results[i], onTap: () => context.read<PlayerProvider>().playQueue(_results, i)),
                  ),
                ),
        ),
      ]),
    );
  }
}
