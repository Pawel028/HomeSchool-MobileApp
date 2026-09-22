import 'package:homeschooling/models/json.dart';

/// One option / item / pair member of a step: `{id, label}`.
class Choice {
  const Choice(this.id, this.label);

  final String id;
  final String label;

  factory Choice.fromJson(Map<String, dynamic> j) => Choice(reqString(j, 'id'), optString(j, 'label') ?? '');
}

List<Choice> _choices(Object? value) => mapList<Choice>(value, Choice.fromJson);

/// A step of an activity definition (schemas/activity-content.schema.json). The server never sends answer keys.
sealed class ActivityStep {
  const ActivityStep({required this.id, required this.type, this.hint});

  final String id;
  final String type;
  final String? hint;

  /// True when the child gives an answer that is sent to the server.
  bool get takesAnswer => false;

  /// False for steps that are never shown to the child (parent_checklist and unknown future types).
  bool get childVisible => true;

  factory ActivityStep.fromJson(Map<String, dynamic> j) {
    final String id = reqString(j, 'id');
    final String type = reqString(j, 'type');
    final String? hint = optString(j, 'hint');
    final String prompt = optString(j, 'prompt') ?? '';
    switch (type) {
      case 'instruction':
        return InstructionStep(id: id, hint: hint, text: optString(j, 'text') ?? '');
      case 'media_prompt':
        return MediaPromptStep(
            id: id, hint: hint, caption: optString(j, 'caption') ?? '', altText: optString(j, 'alt_text') ?? '');
      case 'single_choice':
        return SingleChoiceStep(id: id, hint: hint, prompt: prompt, options: _choices(j['options']));
      case 'multi_choice':
        return MultiChoiceStep(id: id, hint: hint, prompt: prompt, options: _choices(j['options']));
      case 'numeric_input':
        return NumericInputStep(id: id, hint: hint, prompt: prompt);
      case 'short_text':
        return ShortTextStep(id: id, hint: hint, prompt: prompt, maxLen: optInt(j, 'max_len') ?? 200);
      case 'sequence_order':
        return SequenceOrderStep(id: id, hint: hint, prompt: prompt, items: _choices(j['items']));
      case 'match_pairs':
        return MatchPairsStep(
            id: id, hint: hint, prompt: prompt, left: _choices(j['left']), right: _choices(j['right']));
      case 'timer_task':
        return TimerTaskStep(
          id: id,
          hint: hint,
          prompt: prompt,
          durationSec: optInt(j, 'duration_sec') ?? 60,
          checklist: stringList(j, 'checklist'),
        );
      case 'reflection':
        return ReflectionStep(id: id, hint: hint, prompt: prompt, emojiOptions: stringList(j, 'emoji_options'));
      case 'audio_record':
      case 'photo_evidence':
        return CaptureStep(id: id, type: type, hint: hint, prompt: prompt, optional: boolOr(j, 'optional'));
      case 'parent_checklist':
        return ParentChecklistStep(
          id: id,
          hint: hint,
          prompt: prompt,
          skillCode: optString(j, 'skill_code') ?? '',
        );
      default:
        return UnknownStep(id: id, type: type);
    }
  }
}

final class InstructionStep extends ActivityStep {
  const InstructionStep({required String id, String? hint, required this.text})
      : super(id: id, type: 'instruction', hint: hint);

  final String text;
}

final class MediaPromptStep extends ActivityStep {
  const MediaPromptStep({required String id, String? hint, required this.caption, required this.altText})
      : super(id: id, type: 'media_prompt', hint: hint);

  final String caption;
  final String altText;
}

final class SingleChoiceStep extends ActivityStep {
  const SingleChoiceStep({required String id, String? hint, required this.prompt, required this.options})
      : super(id: id, type: 'single_choice', hint: hint);

  final String prompt;
  final List<Choice> options;

  @override
  bool get takesAnswer => true;
}

final class MultiChoiceStep extends ActivityStep {
  const MultiChoiceStep({required String id, String? hint, required this.prompt, required this.options})
      : super(id: id, type: 'multi_choice', hint: hint);

  final String prompt;
  final List<Choice> options;

  @override
  bool get takesAnswer => true;
}

final class NumericInputStep extends ActivityStep {
  const NumericInputStep({required String id, String? hint, required this.prompt})
      : super(id: id, type: 'numeric_input', hint: hint);

  final String prompt;

  @override
  bool get takesAnswer => true;
}

final class ShortTextStep extends ActivityStep {
  const ShortTextStep({required String id, String? hint, required this.prompt, required this.maxLen})
      : super(id: id, type: 'short_text', hint: hint);

  final String prompt;
  final int maxLen;

  @override
  bool get takesAnswer => true;
}

final class SequenceOrderStep extends ActivityStep {
  const SequenceOrderStep({required String id, String? hint, required this.prompt, required this.items})
      : super(id: id, type: 'sequence_order', hint: hint);

  final String prompt;

  /// Items as delivered by the server. The player shuffles them for display.
  final List<Choice> items;

  @override
  bool get takesAnswer => true;
}

final class MatchPairsStep extends ActivityStep {
  const MatchPairsStep({
    required String id,
    String? hint,
    required this.prompt,
    required this.left,
    required this.right,
  }) : super(id: id, type: 'match_pairs', hint: hint);

  final String prompt;
  final List<Choice> left;
  final List<Choice> right;

  @override
  bool get takesAnswer => true;
}

final class TimerTaskStep extends ActivityStep {
  const TimerTaskStep({
    required String id,
    String? hint,
    required this.prompt,
    required this.durationSec,
    required this.checklist,
  }) : super(id: id, type: 'timer_task', hint: hint);

  final String prompt;
  final int durationSec;
  final List<String> checklist;

  @override
  bool get takesAnswer => true;
}

final class ReflectionStep extends ActivityStep {
  const ReflectionStep({required String id, String? hint, required this.prompt, required this.emojiOptions})
      : super(id: id, type: 'reflection', hint: hint);

  final String prompt;
  final List<String> emojiOptions;

  @override
  bool get takesAnswer => true;
}

/// audio_record and photo_evidence: MVP asks the child to do it with a grown-up (nothing is recorded by the app).
final class CaptureStep extends ActivityStep {
  const CaptureStep({
    required String id,
    required String type,
    String? hint,
    required this.prompt,
    required this.optional,
  }) : super(id: id, type: type, hint: hint);

  final String prompt;
  final bool optional;
}

final class ParentChecklistStep extends ActivityStep {
  const ParentChecklistStep({required String id, String? hint, required this.prompt, required this.skillCode})
      : super(id: id, type: 'parent_checklist', hint: hint);

  final String prompt;
  final String skillCode;

  @override
  bool get childVisible => false;
}

/// A step type this app version does not know: skipped in the child flow instead of crashing.
final class UnknownStep extends ActivityStep {
  const UnknownStep({required String id, required String type}) : super(id: id, type: type);

  @override
  bool get childVisible => false;
}

class ActivityDefinition {
  const ActivityDefinition({
    required this.slug,
    required this.title,
    required this.steps,
    this.summary,
    this.subject = '',
    this.durationMin = 0,
    this.materials = const <String>[],
    this.skills = const <String>[],
  });

  final String slug;
  final String title;
  final String? summary;
  final String subject;
  final int durationMin;
  final List<String> materials;
  final List<String> skills;
  final List<ActivityStep> steps;

  /// Steps the child sees, in order.
  List<ActivityStep> get childSteps => steps.where((ActivityStep s) => s.childVisible).toList();

  /// Steps a parent rates after the session.
  List<ParentChecklistStep> get checklistSteps => steps.whereType<ParentChecklistStep>().toList();

  factory ActivityDefinition.fromJson(Map<String, dynamic> j) => ActivityDefinition(
        slug: optString(j, 'slug') ?? '',
        title: optString(j, 'title') ?? '',
        summary: optString(j, 'summary'),
        subject: optString(j, 'subject') ?? '',
        durationMin: optInt(j, 'duration_min') ?? 0,
        materials: stringList(j, 'materials'),
        skills: stringList(j, 'skills'),
        steps: mapList<ActivityStep>(j['steps'], ActivityStep.fromJson),
      );
}
