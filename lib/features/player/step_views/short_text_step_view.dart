import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';
import 'package:homeschooling/strings.dart';

class ShortTextStepView extends StatefulWidget {
  const ShortTextStepView({super.key, required this.step, required this.answer, required this.onChanged});

  final ShortTextStep step;
  final String? answer;
  final ValueChanged<String> onChanged;

  @override
  State<ShortTextStepView> createState() => _ShortTextStepViewState();
}

class _ShortTextStepViewState extends State<ShortTextStepView> {
  late final TextEditingController _controller = TextEditingController(text: widget.answer ?? '');

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
          maxLength: widget.step.maxLen,
          maxLines: 3,
          decoration: const InputDecoration(hintText: Str.shortTextHint, border: OutlineInputBorder()),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
