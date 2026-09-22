import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/state/auth_providers.dart';
import 'package:homeschooling/state/child_mode_providers.dart';
import 'package:homeschooling/state/family_providers.dart';
import 'package:homeschooling/state/router_guard.dart';
import 'package:homeschooling/strings.dart';

/// "Who's learning today?" — the hand-off screen between a parent and a child sharing one device.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  Future<void> _openChild(BuildContext context, WidgetRef ref, Child child) async {
    final bool ok = await ref.read(activeChildProvider.notifier).enterChildMode(child);
    if (!context.mounted) return;
    if (ok) context.go(Routes.child);
  }

  Future<void> _addChild(BuildContext context, WidgetRef ref) async {
    final bool verified = ref.read(authProvider).family?.guardianVerified ?? false;
    if (!verified) {
      await context.push(Routes.guardian);
      if (!context.mounted) return;
      final bool nowVerified = ref.read(authProvider).family?.guardianVerified ?? false;
      if (!nowVerified) return;
    }
    if (context.mounted) context.push(Routes.addChild);
  }

  void _openParent(BuildContext context, WidgetRef ref) {
    context.go(Routes.parentDashboard);
  }

  Future<void> _editChild(BuildContext context, WidgetRef ref, Child child) async {
    context.push(Routes.editChild(child.id), extra: child);
  }

  Future<void> _deleteChild(BuildContext context, WidgetRef ref, Child child) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text(Str.deleteChildTitle),
        content: const Text(Str.deleteChildBody),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text(Str.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text(Str.deleteChildCta)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final String? token = await context.push<String>(Routes.pinVerify);
    if (token == null || !context.mounted) return;
    await ref.read(familyProvider.notifier).deleteChild(child.id, token);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FamilyState family = ref.watch(familyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Str.whoIsLearning)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(familyProvider.notifier).refresh(),
          child: family.loading && family.children.isEmpty
              ? const LoadingView()
              : family.error != null && family.children.isEmpty
                  ? ErrorView.fromException(family.error!, onRetry: () => ref.read(familyProvider.notifier).refresh())
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: <Widget>[
                          for (final Child child in family.children)
                            _ProfileTile(
                              label: child.displayName,
                              icon: Icons.face,
                              onTap: () => _openChild(context, ref, child),
                              onEdit: () => _editChild(context, ref, child),
                              onDelete: () => _deleteChild(context, ref, child),
                            ),
                          _ProfileTile(label: Str.parentTile, icon: Icons.shield_outlined, onTap: () => _openParent(context, ref)),
                          _ProfileTile(
                            label: Str.addChild,
                            icon: Icons.add_circle_outline,
                            onTap: () => _addChild(context, ref),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.label, required this.icon, required this.onTap, this.onEdit, this.onDelete});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 40),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (String value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(value: 'edit', child: Text(Str.edit)),
                      const PopupMenuItem<String>(value: 'delete', child: Text(Str.delete)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
