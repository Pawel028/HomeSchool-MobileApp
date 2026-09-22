import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homeschooling/features/common/state_views.dart';
import 'package:homeschooling/features/player/step_views/capture_step_view.dart';
import 'package:homeschooling/features/player/step_views/instruction_step_view.dart';
import 'package:homeschooling/features/player/step_views/match_pairs_step_view.dart';
import 'package:homeschooling/features/player/step_views/media_prompt_step_view.dart';
import 'package:homeschooling/features/player/step_views/multi_choice_step_view.dart';
import 'package:homeschooling/features/player/step_views/numeric_input_step_view.dart';
import 'package:homeschooling/features/player/step_views/reflection_step_view.dart';
import 'package:homeschooling/features/player/step_views/sequence_order_step_view.dart';
import 'package:homeschooling/features/player/step_views/short_text_step_view.dart';
import 'package:homeschooling/features/player/step_views/single_choice_step_view.dart';
import 'package:homeschooling/features/player/step_views/timer_task_step_view.dart';
import 'package:homeschooling/models/steps.dart';
import 'package:homeschooling/state/session_player_providers.dart';
import 'package:homeschooling/strings.dart';

/// True once [step] has whatever the server needs to score it (steps that take no answer are always "ready").
bool _isAnswered(ActivityStep step, Map<String, dynamic> answers) {
  if (!step.takesAnswer) return true;
  final Object? value = answers[step.id];
  return switch (step) {
    MultiChoiceStep() => value is List && value.isNotEmpty,
    SequenceOrderStep s => value is List && value.length == s.items.length,
    MatchPairsStep s => value is List && value.length == s.left.length,
    TimerTaskStep() => value == true,
    _ => value != null && value != '',
  };
}

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  Future<bool> _confirmExit(BuildContext context) async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text(Str.playerExitTitle),
        content: const Text(Str.playerExitBody),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text(Str.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text(Str.playerExitCta)),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerState? state = ref.watch(playerProvider);

    if (state == null || state.loading) {
      return const Scaffold(body: LoadingView());
    }
    if (state.error != null && state.definition == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView.fromException(state.error!, onRetry: () => context.pop()),
      );
    }
    if (state.submitted) {
      return _CompletionView(state: state);
    }

    final List<ActivityStep> steps = state.childSteps;
    if (steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(message: Str.emptyGeneric),
      );
    }
    final ActivityStep step = steps[state.stepIndex.clamp(0, steps.length - 1)];
    final bool isLast = state.stepIndex >= steps.length - 1;
    final bool answered = _isAnswered(step, state.answers);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool leave = await _confirmExit(context);
        if (leave && context.mounted) {
          ref.read(playerProvider.notifier).close();
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${Str.stepOfLabel} ${state.stepIndex + 1}/${steps.length}'),
          actions: <Widget>[
            if (step.hint != null)
              IconButton(
                icon: const Icon(Icons.lightbulb_outline),
                tooltip: Str.hintButton,
                onPressed: () => _showHint(context, ref, step.hint!),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                LinearProgressIndicator(value: (state.stepIndex + 1) / steps.length),
                const SizedBox(height: 20),
                Expanded(child: SingleChildScrollView(child: _stepBody(context, ref, step, state))),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: state.parentAssist,
                  title: const Text(Str.grownUpHelped),
                  onChanged: (bool v) => ref.read(playerProvider.notifier).setParentAssist(v),
                ),
                Row(
                  children: <Widget>[
                    if (state.stepIndex > 0)
                      OutlinedButton(
                        onPressed: () => ref.read(playerProvider.notifier).previousStep(),
                        child: const Text(Str.back),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: !answered
                          ? null
                          : () {
                              if (isLast) {
                                ref.read(playerProvider.notifier).finish();
                              } else {
                                ref.read(playerProvider.notifier).nextStep();
                              }
                            },
                      child: state.submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isLast ? Str.playerSubmit : Str.next),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHint(BuildContext context, WidgetRef ref, String hint) {
    ref.read(playerProvider.notifier).useHint();
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text(Str.hintButton),
        content: Text(hint),
        actions: <Widget>[TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text(Str.ok))],
      ),
    );
  }

  Widget _stepBody(BuildContext context, WidgetRef ref, ActivityStep step, PlayerState state) {
    final notifier = ref.read(playerProvider.notifier);
    final Object? value = state.answers[step.id];
    return switch (step) {
      InstructionStep s => InstructionStepView(step: s),
      MediaPromptStep s => MediaPromptStepView(step: s),
      SingleChoiceStep s => SingleChoiceStepView(
          step: s,
          answer: value as String?,
          onChanged: (String v) => notifier.setAnswer(s.id, v),
        ),
      MultiChoiceStep s => MultiChoiceStepView(
          step: s,
          answer: (value as List?)?.cast<String>() ?? const <String>[],
          onChanged: (List<String> v) => notifier.setAnswer(s.id, v),
        ),
      NumericInputStep s => NumericInputStepView(
          step: s,
          answer: value as num?,
          onChanged: (num? v) => notifier.setAnswer(s.id, v),
        ),
      ShortTextStep s => ShortTextStepView(
          step: s,
          answer: value as String?,
          onChanged: (String v) => notifier.setAnswer(s.id, v),
        ),
      SequenceOrderStep s => SequenceOrderStepView(
          step: s,
          answer: (value as List?)?.cast<String>(),
          onChanged: (List<String> v) => notifier.setAnswer(s.id, v),
        ),
      MatchPairsStep s => MatchPairsStepView(
          step: s,
          answer: value == null ? const <List<String>>[] : (value as List).map((Object? e) => (e as List).cast<String>()).toList(),
          onChanged: (List<List<String>> v) => notifier.setAnswer(s.id, v),
        ),
      TimerTaskStep s => TimerTaskStepView(
          step: s,
          done: value == true,
          onChanged: (bool v) => notifier.setAnswer(s.id, v),
        ),
      ReflectionStep s => ReflectionStepView(
          step: s,
          answer: value as String?,
          onChanged: (String v) => notifier.setAnswer(s.id, v),
        ),
      CaptureStep s => CaptureStepView(
          step: s,
          onDone: () => notifier.nextStep(),
          onSkip: () => notifier.nextStep(),
        ),
      ParentChecklistStep() || UnknownStep() => const SizedBox.shrink(),
    };
  }
}

class _CompletionView extends ConsumerWidget {
  const _CompletionView({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double? score = state.result?.score;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.celebration, size: 64, color: Colors.amber),
                const SizedBox(height: 16),
                Text(Str.resultTitle, style: Theme.of(context).textTheme.headlineMedium),
                if (score != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('${(score * 100).round()}%', style: Theme.of(context).textTheme.titleLarge),
                ],
                if (state.result != null && state.result!.needsReview.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  const Text(Str.resultReviewPending, textAlign: TextAlign.center),
                ],
                if (state.queuedOffline) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.cloud_off, size: 18, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 6),
                      Flexible(child: Text(Str.playerOfflineQueued, style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    ref.read(playerProvider.notifier).close();
                    context.pop();
                  },
                  child: const Text(Str.done),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
