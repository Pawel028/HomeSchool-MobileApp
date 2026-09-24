import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homeschooling/core/validators.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/state/auth_providers.dart';
import 'package:homeschooling/state/pin_providers.dart';
import 'package:homeschooling/strings.dart';

/// Set the parent PIN for the first time, or change it (pass [isChange] true — the form then also asks for
/// the current PIN, per `PUT /v1/me/pin {pin, current_pin?}`).
class PinSetScreen extends ConsumerStatefulWidget {
  const PinSetScreen({super.key, this.isChange = false});

  final bool isChange;

  @override
  ConsumerState<PinSetScreen> createState() => _PinSetScreenState();
}

class _PinSetScreenState extends ConsumerState<PinSetScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bool ok = await ref.read(pinProvider.notifier).setPin(
          _pin.text,
          currentPin: widget.isChange ? _current.text : null,
        );
    if (!mounted) return;
    if (ok) {
      await ref.read(authProvider.notifier).refreshMe();
      if (!mounted) return;
      // Hand the just-chosen PIN back to the caller (PinVerifyScreen uses it to auto-verify after a
      // first-time setup, so the parent doesn't have to immediately re-type the PIN they just chose).
      if (context.canPop()) context.pop(_pin.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PinState pin = ref.watch(pinProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.isChange ? Str.pinChangeTitle : Str.pinSetTitle)),
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
                    const Text(Str.pinSetIntro),
                    const SizedBox(height: 16),
                    if (widget.isChange)
                      TextFormField(
                        controller: _current,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: Str.pinCurrentLabel),
                        validator: (String? v) => Validators.isPin(v ?? '') ? null : Str.pinInvalid,
                      ),
                    TextFormField(
                      controller: _pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: Str.pinLabel),
                      validator: (String? v) => Validators.isPin(v ?? '') ? null : Str.pinInvalid,
                    ),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: Str.pinConfirmLabel),
                      validator: (String? v) => v == _pin.text ? null : Str.pinMismatch,
                    ),
                    if (pin.error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(errorText(pin.error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: pin.busy ? null : _submit,
                      child: Text(widget.isChange ? Str.saveChanges : Str.pinSetCta),
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
