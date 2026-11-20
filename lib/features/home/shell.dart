import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/security.dart';
import '../library/library_provider.dart';
import '../library/library_screen.dart';
import '../player/mini_player.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../tracks/tracks_provider.dart';
import 'home_screen.dart';

/// Bottom navigation + a mini player that stays above it on every tab.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TracksProvider>().load();
      context.read<LibraryProvider>().load();
      DeviceSecurity.requestNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [HomeScreen(), SearchScreen(), LibraryScreen(), ProfileScreen()]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        const MiniPlayer(),
        NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'خانه'),
            NavigationDestination(icon: Icon(Icons.search_rounded), label: 'جست‌وجو'),
            NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded), label: 'کتابخانه'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'پروفایل'),
          ],
        ),
      ]),
    );
  }
}
