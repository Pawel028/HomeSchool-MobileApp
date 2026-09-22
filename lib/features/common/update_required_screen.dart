import 'package:flutter/material.dart';
import 'package:homeschooling/strings.dart';

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.system_update, size: 48),
              const SizedBox(height: 16),
              Text(Str.updateRequiredTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(Str.updateRequiredBody, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
