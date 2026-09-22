import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homeschooling/core/auth_tokens.dart';
import 'package:homeschooling/core/dates.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/models/plan.dart';
import 'package:homeschooling/state/child_mode_providers.dart';
import 'package:homeschooling/state/plan_providers.dart';
import 'package:homeschooling/state/router_guard.dart';
import 'package:homeschooling/state/session_player_providers.dart';
import 'package:homeschooling/strings.dart';
import 'package:homeschooling/theme.dart';

/// The child's whole world while the device is in child mode: today's plan and nothing else — no settings,
/// no navigation to parent screens. Leaving requires a grown-up's PIN (see `_switchProfile`).
class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  String? _loadedForChildId;

  @override
  Widget build(BuildContext context) {
    final ActiveChildState active = ref.watch(activeChildProvider);
    final Child? child = active.child;

    if (child != null && _loadedForChildId != child.id) {
      _loadedForChildId = child.id;
      Future<void>.microtask(() => ref.read(todayProvider.notifier).load(child.id, auth: AuthKind.child));
    }

    return PopScope(
      canPop: false,
      child: Theme(
        data: AppTheme.child(Theme.of(context).brightness),
        child: Scaffold(
          appBar: AppBar(
            title: Text(child == null ? Str.appName : Str.greeting(dayPart(DateTime.now()), child.displayName)),
            automaticallyImplyLeading: false,
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: Str.backToParent,
                onPressed: () => _switchProfile(context, ref),
              ),
            ],
          ),
          body: SafeArea(child: _body(active)),
        ),
      ),
    );
  }

  Widget _body(ActiveChildState active) {
    if (active.busy || active.child == null) return const LoadingView();
    final TodayState today = ref.watch(todayProvider);
    if (today.loading && today.items.isEmpty) return const LoadingView();
    if (today.error != null && today.items.isEmpty) {
      return ErrorView.fromException(
        today.error!,
        onRetry: () => ref.read(todayProvider.notifier).load(active.child!.id, auth: AuthKind.child),
      );
    }
    if (today.items.isEmpty) return const EmptyView(message: Str.noActivitiesToday, icon: Icons.wb_sunny_outlined);

    return RefreshIndicator(
      onRefresh: () => ref.read(todayProvider.notifier).load(active.child!.id, auth: AuthKind.child),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: today.items.length,
        itemBuilder: (BuildContext context, int index) => _ActivityCard(item: today.items[index]),
      ),
    );
  }

  Future<void> _switchProfile(BuildContext context, WidgetRef ref) async {
    final String? token = await context.push<String>(Routes.pinVerify);
    if (token == null || !context.mounted) return;
    final bool ok = await ref.read(activeChildProvider.notifier).exitToParentMode(token);
    if (ok && context.mounted) context.go(Routes.profiles);
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({required this.item});

  final PlanItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool done = item.isCompleted;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              child: Icon(done ? Icons.check : Icons.play_arrow, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.activity.title, style: Theme.of(context).textTheme.titleMedium),
                  Text('${item.activity.durationMin} min'),
                ],
              ),
            ),
            if (!done)
              FilledButton(
                onPressed: () => _start(context, ref),
                child: Text(item.status == 'in_progress' ? Str.continueActivity : Str.startActivity),
              ),
          ],
        ),
      ),
    );
  }

  void _start(BuildContext context, WidgetRef ref) {
    final Child? child = ref.read(activeChildProvider).child;
    if (child == null) return;
    ref.read(playerProvider.notifier).open(
          childId: child.id,
          summary: item.activity,
          planItemId: item.id,
        );
    context.push('${Routes.player}/${item.activity.id}');
  }
}
