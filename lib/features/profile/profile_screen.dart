import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/security.dart';
import '../../core/widgets.dart';
import '../auth/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<DeviceSecurity> _sec = DeviceSecurity.check();
  late final Future<bool> _bioAvail = context.read<AuthProvider>().biometricAvailable();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.user;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: kSurface,
            backgroundImage: (u?.avatarUrl.isNotEmpty ?? false) ? NetworkImage(u!.avatarUrl) : null,
            child: (u?.avatarUrl.isNotEmpty ?? false) ? null : const Icon(Icons.person_rounded, size: 34, color: Colors.white54),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u?.shownName ?? '...', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(u?.email ?? '', textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white60)),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        const Text('تنظیمات امنیتی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        FutureBuilder<bool>(
          future: _bioAvail,
          builder: (_, s) {
            final avail = s.data ?? false;
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.fingerprint_rounded, color: kAccent),
              title: const Text('ورود با اثر انگشت / چهره'),
              subtitle: Text(avail ? 'هنگام باز کردن برنامه هویت شما تأیید می‌شود' : 'بیومتریک روی این دستگاه فعال نیست'),
              value: auth.biometricEnabled,
              onChanged: !avail && !auth.biometricEnabled
                  ? null
                  : (v) async {
                      final ok = await auth.setBiometric(v);
                      if (!ok && context.mounted) toast(context, 'تأیید هویت انجام نشد');
                    },
            );
          },
        ),
        FutureBuilder<DeviceSecurity>(
          future: _sec,
          builder: (_, s) {
            final d = s.data;
            if (d == null) return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
            if (!d.known) {
              return const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.help_outline_rounded), title: Text('وضعیت امنیتی دستگاه'), subtitle: Text('بررسی ممکن نبود'));
            }
            return Column(children: [
              _SecRow(ok: !d.rooted, title: 'روت / جیلبریک', okText: 'دستگاه روت نشده است', badText: 'دستگاه روت شده است'),
              _SecRow(ok: !d.emulator, title: 'شبیه‌ساز', okText: 'دستگاه واقعی است', badText: 'برنامه روی شبیه‌ساز اجرا می‌شود'),
            ]);
          },
        ),
        const Divider(height: 32),
        if (auth.biometricEnabled)
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.lock_outline_rounded), title: const Text('قفل کردن برنامه'), onTap: auth.lock),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          title: const Text('خروج از حساب', style: TextStyle(color: Colors.redAccent)),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('خروج از حساب'),
                content: const Text('از حساب خود خارج می‌شوید؟'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
                ],
              ),
            );
            if (ok == true) await auth.signOut();
          },
        ),
      ]),
    );
  }
}

class _SecRow extends StatelessWidget {
  const _SecRow({required this.ok, required this.title, required this.okText, required this.badText});
  final bool ok;
  final String title;
  final String okText;
  final String badText;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(ok ? Icons.verified_user_rounded : Icons.warning_amber_rounded, color: ok ? kAccent : Colors.orange),
        title: Text(title),
        subtitle: Text(ok ? okText : badText),
      );
}
