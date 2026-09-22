import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';

/// MVP has no real media pipeline yet: shows the caption/alt text as a placeholder card instead of an image.
class MediaPromptStepView extends StatelessWidget {
  const MediaPromptStepView({super.key, required this.step});

  final MediaPromptStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 16),
        if (step.caption.isNotEmpty) Text(step.caption, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
      ],
    );
  }
}
