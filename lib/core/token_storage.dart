import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens live ONLY in the platform keystore (flutter_secure_storage),
/// never in SharedPreferences.
class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  Future<String?> get access => _s.read(key: _kAccess);
  Future<String?> get refresh => _s.read(key: _kRefresh);

  Future<void> save(String access, String refresh) async {
    await _s.write(key: _kAccess, value: access);
    await _s.write(key: _kRefresh, value: refresh);
  }

  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
  }
}
