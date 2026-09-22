import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homeschooling/core/validators.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/state/auth_providers.dart';
import 'package:homeschooling/state/router_guard.dart';
import 'package:homeschooling/strings.dart';

/// India-first MVP: the family's timezone is fixed rather than asked for in the form.
const String _kDefaultTimezone = 'Asia/Kolkata';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _familyName = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _familyName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bool ok = await ref.read(authProvider.notifier).signup(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
          timezone: _kDefaultTimezone,
          familyName: _familyName.text,
        );
    if (!mounted) return;
    if (ok) context.go(Routes.profiles);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Str.signupTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(Str.signupWelcome),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullName,
                      decoration: const InputDecoration(labelText: Str.fullNameLabel),
                      validator: (String? v) => (v == null || v.trim().isEmpty) ? Str.invalidFullName : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: const InputDecoration(labelText: Str.emailLabel),
                      validator: (String? v) => Validators.isEmail(v ?? '') ? null : Str.invalidEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      decoration: const InputDecoration(labelText: Str.passwordLabel, helperText: Str.passwordHint),
                      validator: (String? v) => Validators.isPassword(v ?? '') ? null : Str.invalidPassword,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _familyName,
                      decoration: const InputDecoration(labelText: Str.familyNameLabel),
                    ),
                    if (auth.error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(errorText(auth.error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(Str.signupCta),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: auth.busy ? null : () => context.go(Routes.login),
                      child: const Text(Str.haveAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
