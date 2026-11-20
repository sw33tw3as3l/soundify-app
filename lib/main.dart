import 'package:just_audio_background/just_audio_background.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'core/widgets.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_screens.dart';
import 'features/home/shell.dart';
import 'features/library/library_provider.dart';
import 'features/onboarding/intro_screens.dart';
import 'features/player/player_provider.dart';
import 'features/tracks/tracks_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'ir.soundify.audio',
    androidNotificationChannelName: 'Soundify',
    androidNotificationOngoing: true,
  );
  final prefs = await SharedPreferences.getInstance();
  final storage = TokenStorage();
  final api = ApiClient(storage);
  final auth = AuthProvider(api, storage, prefs);
  final library = LibraryProvider(api);
  final tracks = TracksProvider(api);
  final player = PlayerProvider();
  api.onSessionExpired = auth.sessionExpired;
  auth.onSignedOut = () {
    player.stop();
    library.clear();
    tracks.clear();
  };
  auth.init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: tracks),
      ChangeNotifierProvider.value(value: player),
    ],
    child: const SoundifyApp(),
  ));
}

class SoundifyApp extends StatelessWidget {
  const SoundifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: kAccent, brightness: Brightness.dark).copyWith(surface: kBg, primary: kAccent, onPrimary: const Color(0xFF06221B));
    return MaterialApp(
      title: 'Soundify',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(backgroundColor: kBg, elevation: 0, scrolledUnderElevation: 0),
        navigationBarTheme: const NavigationBarThemeData(backgroundColor: kSurface),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      ),
      // Persian: right-to-left everywhere.
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthProvider, AuthStatus>((a) => a.status);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (status) {
        AuthStatus.unknown => const SplashScreen(key: ValueKey('splash')),
        AuthStatus.onboarding => const OnboardingScreen(key: ValueKey('onb')),
        AuthStatus.loggedOut => const LoginScreen(key: ValueKey('login')),
        AuthStatus.locked => const LockScreen(key: ValueKey('lock')),
        AuthStatus.loggedIn => const Shell(key: ValueKey('shell')),
      },
    );
  }
}
