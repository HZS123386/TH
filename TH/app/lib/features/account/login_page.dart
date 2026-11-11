import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool register = false, busy = false;
  String? error;
  Future<void> submit({bool apple = false}) async {
    if (busy) return;
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    if (!apple && register && password.text != confirmation.text) {
      setState(() => error = s.passwordMismatch);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (apple) {
        await d.auth.signInApple();
      } else {
        await d.auth.signInDevelopment(
          username.text,
          password.text,
          register: register,
        );
      }
      if (mounted) context.go('/profile');
    } catch (_) {
      if (mounted) setState(() => error = s.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: d.session,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(s.account, s.accountText),
            FateCard(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      size: 42,
                      color: goldColor,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        busy ||
                            !d.session.capabilities.appleLogin ||
                            kIsWeb ||
                            defaultTargetPlatform != TargetPlatform.iOS
                        ? null
                        : () => submit(apple: true),
                    icon: const Icon(Icons.apple),
                    label: Text(s.appleLogin),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.nativeSetup,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (d.auth.canUseDevelopmentLogin &&
                d.session.capabilities.developmentLogin) ...[
              const SizedBox(height: 22),
              FateCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.developmentLogin,
                      style: const TextStyle(color: goldColor),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: username,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: s.username),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: password,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(labelText: s.password),
                    ),
                    if (register) ...[
                      const SizedBox(height: 15),
                      TextField(
                        controller: confirmation,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: s.confirmPassword,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(register ? s.register : s.login),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => register = !register),
                      child: Text(register ? s.login : s.register),
                    ),
                  ],
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }
}
