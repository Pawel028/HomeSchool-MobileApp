import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';
import 'package:homeschooling/strings.dart';

class ReflectionStepView extends StatelessWidget {
  const ReflectionStepView({super.key, required this.step, required this.answer, required this.onChanged});

  final ReflectionStep step;
  final String? answer;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> emojis = step.emojiOptions.isEmpty ? const <String>['😃', '🙂', '😐', '😕'] : step.emojiOptions;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(step.prompt.isEmpty ? Str.reflectionPrompt : step.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final String emoji in emojis)
              InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () => onChanged(emoji),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: answer == emoji ? Theme.of(context).colorScheme.primaryContainer : null,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 40)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
