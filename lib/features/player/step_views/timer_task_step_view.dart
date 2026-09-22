import 'dart:async';

import 'package:flutter/material.dart';
import 'package:homeschooling/core/dates.dart';
import 'package:homeschooling/models/steps.dart';
import 'package:homeschooling/strings.dart';

/// `timer_task`: a countdown of `duration_sec` plus an optional checklist. The answer (if any) is just
/// `true` once the child marks it done — there is no score to compute client side.
class TimerTaskStepView extends StatefulWidget {
  const TimerTaskStepView({super.key, required this.step, required this.done, required this.onChanged});

  final TimerTaskStep step;
  final bool done;
  final ValueChanged<bool> onChanged;

  @override
  State<TimerTaskStepView> createState() => _TimerTaskStepViewState();
}

class _TimerTaskStepViewState extends State<TimerTaskStepView> {
  late int _remaining = widget.step.durationSec;
  Timer? _timer;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.step.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        Center(
          child: Text(formatMinSec(_remaining), style: Theme.of(context).textTheme.displayMedium),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            onPressed: _remaining == 0 ? null : _toggle,
            child: Text(_running ? Str.timerPause : Str.timerStart),
          ),
        ),
        if (widget.step.checklist.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          for (final String item in widget.step.checklist)
            ListTile(leading: const Icon(Icons.check_circle_outline), title: Text(item)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.done ? null : () => widget.onChanged(true),
          child: Text(widget.done ? Str.done : Str.done),
        ),
      ],
    );
  }
}
