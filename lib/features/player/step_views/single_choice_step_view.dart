import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';

class SingleChoiceStepView extends StatelessWidget {
  const SingleChoiceStepView({super.key, required this.step, required this.answer, required this.onChanged});

  final SingleChoiceStep step;

  /// The selected option id, or null.
  final String? answer;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(step.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        for (final Choice option in step.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => onChanged(option.id),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: answer == option.id ? Theme.of(context).colorScheme.primaryContainer : null,
              ),
              child: Text(option.label, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
      ],
    );
  }
}
