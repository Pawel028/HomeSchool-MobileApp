import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';
import 'package:homeschooling/strings.dart';

/// `audio_record` / `photo_evidence`: MVP does not record anything in-app. The child does the activity with
/// a grown-up and taps Done (or Skip, if [CaptureStep.optional]). No answer is sent for this step.
class CaptureStepView extends StatelessWidget {
  const CaptureStepView({super.key, required this.step, required this.onDone, required this.onSkip});

  final CaptureStep step;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          step.type == 'audio_record' ? Icons.mic_none : Icons.photo_camera_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        if (step.prompt.isNotEmpty) ...<Widget>[
          Text(step.prompt, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
        ],
        const Text(Str.captureDoneWithGrownUp, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(onPressed: onDone, child: const Text(Str.done)),
        if (step.optional) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(onPressed: onSkip, child: const Text(Str.skip)),
        ],
      ],
    );
  }
}
