import 'package:flutter/material.dart';
import 'package:homeschooling/strings.dart';

/// An on-screen numeric keypad for a 4-6 digit PIN. No physical-keyboard dependency (works the same on any
/// device) and no [TextField], so there is nothing for autofill/keyboard suggestions to leak.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onSubmit,
    this.minLength = 4,
    this.maxLength = 6,
    this.errorText,
    this.busy = false,
  });

  final Future<void> Function(String pin) onSubmit;
  final int minLength;
  final int maxLength;
  final String? errorText;
  final bool busy;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';

  @override
  void didUpdateWidget(PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null && widget.errorText != oldWidget.errorText) {
      setState(() => _digits = '');
    }
  }

  void _tap(String digit) {
    if (widget.busy || _digits.length >= widget.maxLength) return;
    setState(() => _digits += digit);
  }

  void _backspace() {
    if (widget.busy || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _submit() async {
    if (widget.busy || _digits.length < widget.minLength) return;
    await widget.onSubmit(_digits);
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _digits.length >= widget.minLength && !widget.busy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(widget.maxLength, (int i) {
            final bool filled = i < _digits.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(widget.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: 260,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (final String d in <String>['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                _PinKey(label: d, onTap: () => _tap(d), enabled: !widget.busy),
              const SizedBox.shrink(),
              _PinKey(label: '0', onTap: () => _tap('0'), enabled: !widget.busy),
              _PinKey(
                icon: Icons.backspace_outlined,
                onTap: _backspace,
                enabled: !widget.busy && _digits.isNotEmpty,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: widget.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(Str.confirm),
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, required this.onTap, this.enabled = true});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Center(
            child: label != null
                ? Text(label!, style: Theme.of(context).textTheme.headlineSmall)
                : Icon(icon, color: enabled ? null : Theme.of(context).disabledColor),
          ),
        ),
      ),
    );
  }
}
