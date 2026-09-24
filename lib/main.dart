import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/app.dart';
import 'package:homeschooling/state/environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppEnvironment environment = await AppEnvironment.bootstrap();
  runApp(
    ProviderScope(
      overrides: [environmentProvider.overrideWithValue(environment)],
      child: const HomeSchoolingApp(),
    ),
  );
}
