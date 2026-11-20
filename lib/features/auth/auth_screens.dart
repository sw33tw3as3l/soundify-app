import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/security.dart';
import '../../core/widgets.dart';
import 'auth_provider.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'ایمیل را وارد کنید';
  if (!_emailRe.hasMatch(s)) return 'ایمیل معتبر نیست';
  return null;
}

String? validatePassword(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'رمز عبور را وارد کنید';
  if (s.length < 8) return 'رمز عبور حداقل ۸ کاراکتر باشد';
  return null;
}

/// After a successful auth the root switches screens; drop any pushed pages.
void _backToRoot(BuildContext context) {
  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, this.subtitle, required this.children, this.showBack = true});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitle!, style: const TextStyle(color: Colors.white60, height: 1.6)),
                ],
                const SizedBox(height: 24),
                ...children,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class SecurityBanner extends StatelessWidget {
  const SecurityBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceSecurity>(
      future: DeviceSecurity.check(),
      builder: (_, s) {
        final d = s.data;
        if (d == null || !d.risky) return const SizedBox.shrink();
        final what = [if (d.rooted) 'روت‌شده', if (d.emulator) 'شبیه‌ساز'].join(' و ');
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.5))),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text('هشدار امنیتی: این دستگاه $what است.', style: const TextStyle(fontSize: 13))),
          ]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    try {
      await auth.login(_email.text, _pass.text);
    } catch (e) {
      final err = ApiError.from(e);
      if (!mounted) return;
      final needsVerify = err.status == 403 && (err.message.contains('verif') || err.message.contains('تأیید') || (err.code ?? '').contains('verif'));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err.message),
        behavior: SnackBarBehavior.floating,
        action: needsVerify
            ? SnackBarAction(
                label: 'تأیید ایمیل',
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => OtpScreen(email: _email.text.trim(), sendOnOpen: true, password: _pass.text))),
              )
            : null,
      ));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: false,
      title: 'ورود به سومیفای',
      subtitle: 'موسیقی مورد علاقه‌ات را هر جا بشنو.',
      children: [
        const SecurityBanner(),
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'ایمیل', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _hide,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'رمز عبور',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
              ),
              validator: validatePassword,
              onFieldSubmitted: (_) => _submit(),
            ),
          ]),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ResetScreen(email: _email.text.trim()))),
            child: const Text('رمز عبور را فراموش کرده‌اید؟'),
          ),
        ),
        const SizedBox(height: 4),
        PrimaryButton(label: 'ورود', onPressed: _submit, loading: _busy),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.pin_outlined),
          label: const Text('ورود با کد یک‌بار مصرف'),
          onPressed: () async {
            final email = await _askEmail(context, _email.text.trim());
            if (email != null && context.mounted) {
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => OtpScreen(email: email, sendOnOpen: true)));
            }
          },
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('حساب ندارید؟'),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const RegisterScreen())), child: const Text('ثبت‌نام')),
        ]),
      ],
    );
  }
}

Future<String?> _askEmail(BuildContext context, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String? err;
      return StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('ایمیل خود را وارد کنید'),
          content: TextField(controller: c, autofocus: true, textDirection: TextDirection.ltr, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'ایمیل', errorText: err)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                final e = validateEmail(c.text);
                if (e != null) {
                  setS(() => err = e);
                  return;
                }
                Navigator.pop(ctx, c.text.trim());
              },
              child: const Text('ارسال کد'),
            ),
          ],
        ),
      );
    },
  );
}

// ------------------------------------------------------------- register

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().register(_email.text, _username.text, _pass.text, _name.text);
      if (!mounted) return;
      toast(context, 'کد تأیید به ایمیل شما ارسال شد');
      await Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => OtpScreen(email: _email.text.trim(), password: _pass.text)));
      return;
    } catch (e) {
      if (mounted) toast(context, ApiError.from(e).message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'ساخت حساب',
      subtitle: 'چند ثانیه وقت می‌گیرد. کد تأیید به ایمیلت می‌آید.',
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'نام نمایشی (اختیاری)', prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 14),
            TextFormField(
              controller: _username,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'نام کاربری', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) => (v ?? '').trim().length < 3 ? 'نام کاربری حداقل ۳ کاراکتر باشد' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'ایمیل', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _hide,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'رمز عبور (حداقل ۸ کاراکتر)',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
              ),
              validator: validatePassword,
            ),
          ]),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'ثبت‌نام', onPressed: _submit, loading: _busy),
      ],
    );
  }
}

// ------------------------------------------------------------------ otp

/// Used for: confirming a new account, and logging in with a one-time code.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.email, this.sendOnOpen = false, this.password});
  final String email;
  final bool sendOnOpen;
  final String? password;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _left = 60;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.sendOnOpen) {
      _left = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    } else {
      _startCountdown(60);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int s) {
    _timer?.cancel();
    setState(() => _left = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  Future<void> _send() async {
    try {
      final s = await context.read<AuthProvider>().requestOtp(widget.email);
      if (mounted) {
        toast(context, 'کد ارسال شد');
        _startCountdown(s);
      }
    } catch (e) {
      if (mounted) toast(context, ApiError.from(e).message);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 4) {
      toast(context, 'کد را وارد کنید');
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    try {
      final loggedIn = await auth.verifyOtp(widget.email, _code.text);
      if (!mounted) return;
      if (loggedIn) {
        _backToRoot(context);
        return;
      }
      if (widget.password != null) {
        await auth.login(widget.email, widget.password!);
        _backToRoot(context);
        return;
      }
      toast(context, 'ایمیل تأیید شد. اکنون با رمز عبور وارد شوید.');
      _backToRoot(context);
      return;
    } catch (e) {
      if (mounted) toast(context, ApiError.from(e).message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'کد تأیید',
      subtitle: 'کد ارسال‌شده به ${widget.email} را وارد کنید.',
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLength: 8,
          style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'تأیید', onPressed: _verify, loading: _busy),
        const SizedBox(height: 12),
        Center(
          child: _left > 0
              ? Text('ارسال مجدد تا $_left ثانیه دیگر', style: const TextStyle(color: Colors.white54))
              : TextButton(onPressed: _send, child: const Text('ارسال مجدد کد')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- reset

class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key, this.email = ''});
  final String email;
  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  late final TextEditingController _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _pass = TextEditingController();
  Timer? _timer;
  int _left = 0;
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _countdown(int s) {
    _timer?.cancel();
    setState(() => _left = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  Future<void> _request() async {
    final e = validateEmail(_email.text);
    if (e != null) {
      toast(context, e);
      return;
    }
    setState(() => _busy = true);
    try {
      final s = await context.read<AuthProvider>().requestReset(_email.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _countdown(s);
      toast(context, 'کد بازیابی ارسال شد');
    } catch (e) {
      if (mounted) toast(context, ApiError.from(e).message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirm() async {
    final pe = validatePassword(_pass.text);
    if (_code.text.trim().isEmpty || pe != null) {
      toast(context, _code.text.trim().isEmpty ? 'کد را وارد کنید' : pe!);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().confirmReset(_email.text, _code.text, _pass.text);
      if (!mounted) return;
      toast(context, 'رمز عبور تغییر کرد. وارد شوید.');
      Navigator.pop(context);
      return;
    } catch (e) {
      if (mounted) toast(context, ApiError.from(e).message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'بازیابی رمز عبور',
      subtitle: _codeSent ? 'کد ارسال‌شده و رمز جدید را وارد کنید.' : 'ایمیل حساب خود را وارد کنید تا کد بازیابی بفرستیم.',
      children: [
        TextField(
          controller: _email,
          enabled: !_codeSent,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'ایمیل', prefixIcon: Icon(Icons.mail_outline_rounded)),
        ),
        if (_codeSent) ...[
          const SizedBox(height: 14),
          TextField(controller: _code, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'کد بازیابی', prefixIcon: Icon(Icons.pin_outlined))),
          const SizedBox(height: 14),
          TextField(controller: _pass, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رمز جدید (حداقل ۸ کاراکتر)', prefixIcon: Icon(Icons.lock_outline_rounded))),
        ],
        const SizedBox(height: 20),
        PrimaryButton(label: _codeSent ? 'ثبت رمز جدید' : 'ارسال کد', onPressed: _codeSent ? _confirm : _request, loading: _busy),
        if (_codeSent)
          Center(
            child: _left > 0
                ? Padding(padding: const EdgeInsets.only(top: 12), child: Text('ارسال مجدد تا $_left ثانیه دیگر', style: const TextStyle(color: Colors.white54)))
                : TextButton(onPressed: _request, child: const Text('ارسال مجدد کد')),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------- lock screen

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await context.read<AuthProvider>().unlock();
    if (!ok && mounted) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: false,
      title: 'سومیفای قفل است',
      subtitle: _failed ? 'تأیید هویت انجام نشد.' : 'برای ادامه با اثر انگشت یا چهره وارد شوید.',
      children: [
        const Icon(Icons.fingerprint_rounded, size: 96, color: kAccent),
        const SizedBox(height: 24),
        PrimaryButton(label: 'ورود با بیومتریک', onPressed: _unlock),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.read<AuthProvider>().usePassword(), child: const Text('ورود با رمز عبور')),
      ],
    );
  }
}
