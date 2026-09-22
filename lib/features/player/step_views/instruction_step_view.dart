import 'package:flutter/material.dart';
import 'package:homeschooling/models/steps.dart';

class InstructionStepView extends StatelessWidget {
  const InstructionStepView({super.key, required this.step});

  final InstructionStep step;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(step.text, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
    );
  }
}
