import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/models/remote_config.dart';
import 'package:homeschooling/state/config_providers.dart';
import 'package:homeschooling/strings.dart';

/// Shown while `GET /v1/config` loads (and while a stored session is being restored). The router redirects
/// away from here automatically once both are resolved; see router_guard.dart.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RemoteConfig> config = ref.watch(remoteConfigProvider);
    return Scaffold(
      body: config.when(
        data: (_) => const LoadingView(label: Str.loading),
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          message: Str.errorNetwork,
          onRetry: () => ref.invalidate(remoteConfigProvider),
        ),
      ),
    );
  }
}
