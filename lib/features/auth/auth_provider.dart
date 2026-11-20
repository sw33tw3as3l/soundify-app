import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/token_storage.dart';

enum AuthStatus { unknown, onboarding, loggedOut, locked, loggedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.api, this.storage, this.prefs);

  final ApiClient api;
  final TokenStorage storage;
  final SharedPreferences prefs;
  final LocalAuthentication _bio = LocalAuthentication();

  AuthStatus status = AuthStatus.unknown;
  UserInfo? user;
  bool biometricEnabled = false;
  VoidCallback? onSignedOut;

  Future<void> init() async {
    final started = DateTime.now();
    biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final onboarded = prefs.getBool('onboarded') ?? false;
    final hasSession = await storage.refresh != null;
    AuthStatus next;
    if (!onboarded) {
      next = AuthStatus.onboarding;
    } else if (!hasSession) {
      next = AuthStatus.loggedOut;
    } else if (biometricEnabled) {
      next = AuthStatus.locked;
    } else {
      next = AuthStatus.loggedIn;
    }
    final wait = const Duration(milliseconds: 1600) - DateTime.now().difference(started);
    if (!wait.isNegative) await Future.delayed(wait);
    status = next;
    notifyListeners();
    if (next == AuthStatus.loggedIn) loadMe();
  }

  Future<void> finishOnboarding() async {
    await prefs.setBool('onboarded', true);
    status = AuthStatus.loggedOut;
    notifyListeners();
  }

  Future<void> loadMe() async {
    try {
      user = UserInfo.fromJson(await api.getMap('/users/me'));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _storeTokens(Map<String, dynamic> d) async {
    await storage.save('${d['access']}', '${d['refresh']}');
    if (d['user'] is Map) user = UserInfo.fromJson(Map<String, dynamic>.from(d['user'] as Map));
    status = AuthStatus.loggedIn;
    notifyListeners();
    if (user == null) loadMe();
  }

  Future<void> login(String email, String password) async {
    final d = await api.postMap('/auth/login', {'email': email.trim(), 'password': password}, auth: false);
    await _storeTokens(d);
  }

  Future<void> register(String email, String username, String password, String displayName) async {
    await api.postMap(
      '/auth/register',
      {
        'email': email.trim(),
        'username': username.trim(),
        'password': password,
        if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
      },
      auth: false,
    );
  }

  /// Returns seconds until the code may be requested again.
  Future<int> requestOtp(String email) async {
    final d = await api.postMap('/auth/otp/request', {'email': email.trim()}, auth: false);
    return (d['resend_after'] as num?)?.toInt() ?? 60;
  }

  /// Returns true when the server also returned tokens (user is now logged in).
  Future<bool> verifyOtp(String email, String code) async {
    final d = await api.postMap('/auth/otp/verify', {'email': email.trim(), 'code': code.trim()}, auth: false);
    if (d['access'] != null && d['refresh'] != null) {
      await _storeTokens(d);
      return true;
    }
    return false;
  }

  Future<int> requestReset(String email) async {
    final d = await api.postMap('/auth/password/reset/request', {'email': email.trim()}, auth: false);
    return (d['resend_after'] as num?)?.toInt() ?? 60;
  }

  Future<void> confirmReset(String email, String code, String newPassword) async {
    await api.postMap(
      '/auth/password/reset/confirm',
      {'email': email.trim(), 'code': code.trim(), 'new_password': newPassword},
      auth: false,
    );
  }

  // ---- biometrics ----

  Future<bool> biometricAvailable() async {
    try {
      return await _bio.isDeviceSupported() && (await _bio.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _bio.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBiometric(bool on) async {
    if (on) {
      if (!await biometricAvailable()) return false;
      if (!await _authenticate('برای فعال‌سازی ورود بیومتریک هویت خود را تأیید کنید')) return false;
    }
    biometricEnabled = on;
    await prefs.setBool('biometric_enabled', on);
    notifyListeners();
    return true;
  }

  Future<bool> unlock() async {
    if (!await _authenticate('برای ورود به سومیفای هویت خود را تأیید کنید')) return false;
    status = AuthStatus.loggedIn;
    notifyListeners();
    loadMe();
    return true;
  }

  /// Keep the session but require biometrics again.
  void lock() {
    if (!biometricEnabled) return;
    onSignedOut?.call();
    status = AuthStatus.locked;
    notifyListeners();
  }

  /// Forget the biometric lock screen and go to the login form (tokens stay
  /// in secure storage only while biometrics are enabled).
  Future<void> usePassword() async {
    await signOut();
  }

  Future<void> signOut() async {
    final refresh = await storage.refresh;
    try {
      await api.run(() => api.dio.post('/auth/logout', data: {if (refresh != null) 'refresh': refresh}));
    } catch (_) {}
    await _clear();
  }

  void sessionExpired() {
    if (status == AuthStatus.loggedIn || status == AuthStatus.locked) {
      _clear();
    }
  }

  Future<void> _clear() async {
    await storage.clear();
    user = null;
    biometricEnabled = false;
    await prefs.setBool('biometric_enabled', false);
    onSignedOut?.call();
    status = AuthStatus.loggedOut;
    notifyListeners();
  }
}
