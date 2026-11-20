import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../auth/auth_provider.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(28)),
            child: const Icon(Icons.graphic_eq_rounded, size: 56, color: Color(0xFF06221B)),
          ),
          const SizedBox(height: 20),
          const Text('Soundify', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 28),
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ]),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  static const _pages = [
    (Icons.library_music_rounded, 'همه موسیقی‌ها، یک‌جا', 'آهنگ‌های منتخب و تازه را مرور کن و با جست‌وجوی زنده سریع پیدا کن.'),
    (Icons.queue_music_rounded, 'پلی‌لیست خودت را بساز', 'آهنگ‌ها را لایک کن، پلی‌لیست بساز و همه‌چیز با سرور هماهنگ می‌ماند.'),
    (Icons.headphones_rounded, 'پخش بدون وقفه', 'با خروج از برنامه یا خاموش شدن صفحه هم پخش ادامه دارد و از اعلان کنترلش می‌کنی.'),
  ];

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: () => context.read<AuthProvider>().finishOnboarding(), child: const Text('رد کردن')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final p = _pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(p.$1, size: 70, color: kAccent),
                    ),
                    const SizedBox(height: 32),
                    Text(p.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(p.$3, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.7)),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                width: i == _i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(color: i == _i ? kAccent : Colors.white24, borderRadius: BorderRadius.circular(4)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryButton(
              label: last ? 'شروع' : 'بعدی',
              onPressed: () => last
                  ? context.read<AuthProvider>().finishOnboarding()
                  : _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
            ),
          ),
        ]),
      ),
    );
  }
}
