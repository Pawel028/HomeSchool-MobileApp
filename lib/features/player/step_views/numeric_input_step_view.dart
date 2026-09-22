import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';
import 'package:homeschooling/strings.dart';

class NumericInputStepView extends StatefulWidget {
  const NumericInputStepView({super.key, required this.step, required this.answer, required this.onChanged});

  final NumericInputStep step;
  final num? answer;
  final ValueChanged<num?> onChanged;

  @override
  State<NumericInputStepView> createState() => _NumericInputStepViewState();
}

class _NumericInputStepViewState extends State<NumericInputStepView> {
  late final TextEditingController _controller = TextEditingController(text: widget.answer?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.step.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: const InputDecoration(hintText: Str.numericInputHint, border: OutlineInputBorder()),
          onChanged: (String v) => widget.onChanged(num.tryParse(v)),
        ),
      ],
    );
  }
}
