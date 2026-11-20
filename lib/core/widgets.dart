import 'package:material_ui/material_ui.dart';
import '../features/tracks/tracks_provider.dart';

const kAccent = Color(0xFF2DD4A7);
const kBg = Color(0xFF0B0F14);
const kSurface = Color(0xFF141A22);

String fmtDur(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

class Cover extends StatelessWidget {
  const Cover(this.url, {super.key, this.size = 52, this.radius = 10});
  final String url;
  final double size;
  final double radius;

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: kSurface,
        child: Icon(Icons.music_note_rounded, color: Colors.white24, size: size * 0.45),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? _placeholder()
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Loading / empty / error (with retry) / content.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.state,
    required this.onRetry,
    required this.builder,
    this.error,
    this.emptyText = 'چیزی برای نمایش نیست.',
    this.emptyIcon = Icons.library_music_outlined,
  });
  final LoadState state;
  final String? error;
  final VoidCallback onRetry;
  final WidgetBuilder builder;
  final String emptyText;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case LoadState.idle:
      case LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              Text(error ?? 'خطا در دریافت اطلاعات', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: const Text('تلاش مجدد')),
            ]),
          ),
        );
      case LoadState.empty:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(emptyIcon, size: 52, color: Colors.white24),
            const SizedBox(height: 12),
            Text(emptyText, style: const TextStyle(color: Colors.white54)),
          ]),
        );
      case LoadState.ready:
        return builder(context);
    }
  }
}
