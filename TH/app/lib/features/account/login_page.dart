import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/network/api_client.dart';
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
      confirmation = TextEditingController(),
      h5Code = TextEditingController();
  bool register = false, busy = false;
  String? error, h5Error;
  Future<void> submitH5Code() async {
    if (busy) return;
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    setState(() {
      busy = true;
      h5Error = null;
    });
    try {
      await d.auth.signInH5Code(h5Code.text);
      if (mounted) context.go('/reports');
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(
          () => h5Error = switch (failure.code) {
            'h5_login_code_invalid' => s.h5CodeInvalid,
            'too_many_requests' => s.h5CodeRateLimited,
            _ => s.error,
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => h5Error = s.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
            PageHeading(s.account, s.accountText, icon: Icons.lock_outline),
            FateCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.h5CodeLogin,
                    style: const TextStyle(color: goldColor, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(s.h5CodeHelp),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('h5-code-input'),
                    controller: h5Code,
                    enabled: !busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    decoration: InputDecoration(labelText: s.h5CodeField),
                    onSubmitted: (_) => submitH5Code(),
                  ),
                  FilledButton(
                    key: const ValueKey('h5-code-submit'),
                    onPressed: busy ? null : submitH5Code,
                    child: Text(busy ? s.waiting : s.login),
                  ),
                  if (h5Error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        h5Error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),
            if (d.session.capabilities.appleLogin &&
                !kIsWeb &&
                defaultTargetPlatform == TargetPlatform.iOS) ...[
              const SizedBox(height: 18),
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
                      onPressed: busy ? null : () => submit(apple: true),
                      icon: const Icon(Icons.apple),
                      label: Text(s.appleLogin),
                    ),
                  ],
                ),
              ),
            ],
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
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: busy ? null : () => context.push('/privacy'),
                  child: Text(s.privacyCenter),
                ),
                TextButton(
                  onPressed: busy ? null : () => context.push('/support'),
                  child: Text(s.termsTitle),
                ),
              ],
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
    h5Code.dispose();
    super.dispose();
  }
}
