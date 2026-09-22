import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';

class MultiChoiceStepView extends StatelessWidget {
  const MultiChoiceStepView({super.key, required this.step, required this.answer, required this.onChanged});

  final MultiChoiceStep step;

  /// Selected option ids.
  final List<String> answer;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(step.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        for (final Choice option in step.options)
          CheckboxListTile(
            value: answer.contains(option.id),
            title: Text(option.label),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? checked) {
              final List<String> next = List<String>.of(answer);
              if (checked ?? false) {
                if (!next.contains(option.id)) next.add(option.id);
              } else {
                next.remove(option.id);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}
