import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/features/parent/parent_scaffold.dart';
import 'package:homeschooling/models/child.dart';
import 'package:homeschooling/models/curriculum.dart';
import 'package:homeschooling/models/progress.dart';
import 'package:homeschooling/state/curriculum_providers.dart';
import 'package:homeschooling/state/parent_view_providers.dart';
import 'package:homeschooling/state/progress_providers.dart';
import 'package:homeschooling/strings.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Child? child = ref.watch(parentViewedChildProvider);
    return ParentScaffold(
      currentPath: '/parent/progress',
      title: Str.progressTitle,
      body: child == null
          ? const EmptyView(message: Str.emptyGeneric, icon: Icons.face_outlined)
          : _MasteryList(child: child),
    );
  }
}

class _MasteryList extends ConsumerWidget {
  const _MasteryList({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Mastery>> mastery = ref.watch(masteryProvider(MasteryQuery(child.id)));
    return mastery.when(
      loading: () => const LoadingView(),
      error: (Object e, StackTrace st) => ErrorView(
        message: errorTextFromAny(e),
        onRetry: () => ref.invalidate(masteryProvider(MasteryQuery(child.id))),
      ),
      data: (List<Mastery> items) {
        if (items.isEmpty) {
          return EmptyView(
            message: Str.baselineChecklistIntro,
            action: FilledButton(
              onPressed: () => _openBaseline(context, ref),
              child: const Text(Str.baselineChecklistTitle),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final Mastery m = items[index];
            return Card(
              child: ListTile(
                title: Text(m.skillName),
                subtitle: Text(m.subjectCode),
                trailing: _StatusChip(status: m.status, needsRevisit: m.needsRevisit),
                onTap: () => _openObservationDialog(context, ref, m),
              ),
            );
          },
        );
      },
    );
  }

  void _openBaseline(BuildContext context, WidgetRef ref) {
    showDialog<void>(context: context, builder: (BuildContext ctx) => _BaselineDialog(child: child));
  }

  void _openObservationDialog(BuildContext context, WidgetRef ref, Mastery mastery) {
    showDialog<void>(context: context, builder: (BuildContext ctx) => _ObservationDialog(child: child, mastery: mastery));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.needsRevisit});

  final String status;
  final bool needsRevisit;

  String get _label {
    switch (status) {
      case 'secure':
        return Str.masterySecure;
      case 'developing':
        return Str.masteryDeveloping;
      default:
        return Str.masteryEmerging;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(needsRevisit ? Str.needsRevisit : _label),
      backgroundColor: needsRevisit ? Theme.of(context).colorScheme.errorContainer : null,
    );
  }
}

class _ObservationDialog extends ConsumerStatefulWidget {
  const _ObservationDialog({required this.child, required this.mastery});

  final Child child;
  final Mastery mastery;

  @override
  ConsumerState<_ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends ConsumerState<_ObservationDialog> {
  String _rating = 'trying';
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> obs = ref.watch(observationsProvider);
    return AlertDialog(
      title: Text(widget.mastery.skillName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(Str.observationRatingLabel),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'trying', label: Text(Str.ratingTrying)),
              ButtonSegment<String>(value: 'with_help', label: Text(Str.ratingWithHelp)),
              ButtonSegment<String>(value: 'independent', label: Text(Str.ratingIndependent)),
            ],
            selected: <String>{_rating},
            onSelectionChanged: (Set<String> s) => setState(() => _rating = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(labelText: Str.observationNoteLabel)),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(Str.cancel)),
        FilledButton(
          onPressed: obs.isLoading
              ? null
              : () async {
                  final bool ok = await ref.read(observationsProvider.notifier).observe(
                        childId: widget.child.id,
                        skillCode: widget.mastery.skillCode,
                        rating: _rating,
                        note: _note.text,
                      );
                  if (ok && context.mounted) Navigator.of(context).pop();
                },
          child: const Text(Str.save),
        ),
      ],
    );
  }
}

class _BaselineDialog extends ConsumerStatefulWidget {
  const _BaselineDialog({required this.child});

  final Child child;

  @override
  ConsumerState<_BaselineDialog> createState() => _BaselineDialogState();
}

class _BaselineDialogState extends ConsumerState<_BaselineDialog> {
  final Map<String, String> _ratings = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> obs = ref.watch(observationsProvider);
    final AsyncValue<List<Skill>> skills =
        ref.watch(skillsProvider(SkillsQuery(level: widget.child.levelCode)));
    return AlertDialog(
      title: const Text(Str.baselineChecklistTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(Str.baselineChecklistIntro),
              const SizedBox(height: 12),
              skills.when(
                loading: () => const LoadingView(),
                error: (Object e, StackTrace st) => Text(errorTextFromAny(e)),
                data: (List<Skill> options) => Column(
                  children: <Widget>[
                    for (final Skill skill in options)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: Text(skill.name)),
                            SegmentedButton<String>(
                              segments: const <ButtonSegment<String>>[
                                ButtonSegment<String>(value: 'trying', label: Text(Str.ratingTrying)),
                                ButtonSegment<String>(value: 'with_help', label: Text(Str.ratingWithHelp)),
                                ButtonSegment<String>(value: 'independent', label: Text(Str.ratingIndependent)),
                              ],
                              selected: <String>{_ratings[skill.code] ?? 'trying'},
                              onSelectionChanged: (Set<String> s) => setState(() => _ratings[skill.code] = s.first),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(Str.cancel)),
        FilledButton(
          onPressed: obs.isLoading
              ? null
              : () async {
                  final bool ok = await ref.read(observationsProvider.notifier).submitBaseline(widget.child.id, _ratings);
                  if (ok && context.mounted) Navigator.of(context).pop();
                },
          child: const Text(Str.save),
        ),
      ],
    );
  }
}
