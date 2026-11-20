import 'package:flutter/services.dart';

class DeviceSecurity {
  final bool rooted;
  final bool emulator;
  final bool known;
  const DeviceSecurity({this.rooted = false, this.emulator = false, this.known = true});

  bool get risky => rooted || emulator;

  static const _ch = MethodChannel('ir.soundify/security');

  static Future<void> requestNotifications() async {
    try {
      await _ch.invokeMethod<void>('requestNotifications');
    } catch (_) {}
  }

  static Future<DeviceSecurity> check() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('check');
      return DeviceSecurity(rooted: m?['rooted'] == true, emulator: m?['emulator'] == true);
    } catch (_) {
      return const DeviceSecurity(known: false);
    }
  }
}
