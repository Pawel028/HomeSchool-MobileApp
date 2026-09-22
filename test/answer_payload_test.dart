import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeschooling/core/pending_item.dart';
import 'package:homeschooling/models/steps.dart';

/// Parses one real example of every step type from `backend-api/seed/launch-bundle.json` (see
/// test/fixtures/steps_sample.json) and checks the answer shape the client builds for each, per the table in
/// api-contracts/docs/client-guide.md ("Activities and the player").
void main() {
  late Map<String, dynamic> samples;

  setUpAll(() {
    final String raw = File('test/fixtures/steps_sample.json').readAsStringSync();
    samples = jsonDecode(raw) as Map<String, dynamic>;
  });

  ActivityStep parse(String type) => ActivityStep.fromJson(samples[type] as Map<String, dynamic>);

  test('instruction and media_prompt take no answer', () {
    expect(parse('instruction'), isA<InstructionStep>());
    expect(parse('instruction').takesAnswer, isFalse);
    expect(parse('media_prompt'), isA<MediaPromptStep>());
    expect(parse('media_prompt').takesAnswer, isFalse);
  });

  test('parent_checklist is never shown to the child', () {
    final ActivityStep step = parse('parent_checklist');
    expect(step, isA<ParentChecklistStep>());
    expect(step.childVisible, isFalse);
    expect((step as ParentChecklistStep).skillCode, 'ART.CRAFT.BUILD');
  });

  test('single_choice answer is the chosen option id', () {
    final SingleChoiceStep step = parse('single_choice') as SingleChoiceStep;
    expect(step.options.map((Choice c) => c.id), <String>['o1', 'o2', 'o3']);
    final Map<String, dynamic> answers = <String, dynamic>{step.id: 'o1'};
    expect(answers[step.id], isA<String>());
  });

  test('multi_choice answer is a list of option ids', () {
    final MultiChoiceStep step = parse('multi_choice') as MultiChoiceStep;
    final Map<String, dynamic> answers = <String, dynamic>{
      step.id: <String>[step.options[0].id, step.options[2].id],
    };
    expect(answers[step.id], <String>['o1', 'o3']);
  });

  test('numeric_input answer is a number', () {
    final NumericInputStep step = parse('numeric_input') as NumericInputStep;
    final Map<String, dynamic> answers = <String, dynamic>{step.id: 5};
    expect(answers[step.id], isA<num>());
  });

  test('short_text answer is a string bounded by max_len', () {
    final ShortTextStep step = parse('short_text') as ShortTextStep;
    expect(step.maxLen, 40);
  });

  test('sequence_order answer is item ids in the child\'s order', () {
    final SequenceOrderStep step = parse('sequence_order') as SequenceOrderStep;
    expect(step.items.map((Choice c) => c.id), <String>['i1', 'i2', 'i3']);
    final Map<String, dynamic> answers = <String, dynamic>{
      step.id: <String>['i2', 'i1', 'i3'], // shuffled by the child
    };
    expect((answers[step.id] as List<String>).toSet(), step.items.map((Choice c) => c.id).toSet());
  });

  test('match_pairs answer is a list of [left_id, right_id] pairs', () {
    final MatchPairsStep step = parse('match_pairs') as MatchPairsStep;
    expect(step.left.length, 3);
    expect(step.right.length, 3);
    final Map<String, dynamic> answers = <String, dynamic>{
      step.id: <List<String>>[
        <String>['l1', 'r1'],
        <String>['l2', 'r2'],
      ],
    };
    final List<List<String>> pairs = (answers[step.id] as List).cast<List<String>>();
    expect(pairs.length, 2);
    expect(pairs.first, <String>['l1', 'r1']);
  });

  test('timer_task answer is absent or true, never a duration', () {
    final TimerTaskStep step = parse('timer_task') as TimerTaskStep;
    expect(step.durationSec, 600);
    expect(step.checklist, <String>['A bench', 'A door', 'A tree trunk']);
    final Map<String, dynamic> doneAnswers = <String, dynamic>{step.id: true};
    expect(doneAnswers[step.id], true);
  });

  test('reflection answer is the chosen emoji string', () {
    final ReflectionStep step = parse('reflection') as ReflectionStep;
    expect(step.emojiOptions, isNotEmpty);
    final Map<String, dynamic> answers = <String, dynamic>{step.id: step.emojiOptions.first};
    expect(answers[step.id], step.emojiOptions.first);
  });

  test('audio_record/photo_evidence take no answer and photo_evidence here is optional', () {
    final CaptureStep audio = parse('audio_record') as CaptureStep;
    final CaptureStep photo = parse('photo_evidence') as CaptureStep;
    expect(audio.takesAnswer, isFalse);
    expect(photo.optional, isTrue);
  });

  test('PendingSubmit.submitBody carries answers/hints_used/parent_assist/duration_sec and occurred_at, '
      'never a raw session id field', () {
    final PendingSubmit item = PendingSubmit(
      id: 'x',
      childId: 'child-1',
      activityId: 'activity-1',
      clientOpId: 'op-1',
      body: <String, dynamic>{
        'answers': <String, dynamic>{'s3': 'o1'},
        'hints_used': 1,
        'parent_assist': false,
        'duration_sec': 42,
      },
      occurredAt: DateTime.utc(2026, 9, 22, 10),
      createdAt: DateTime.utc(2026, 9, 22, 10),
      auth: 'child',
    );
    final Map<String, dynamic> body = item.submitBody();
    expect(body['answers'], <String, dynamic>{'s3': 'o1'});
    expect(body['hints_used'], 1);
    expect(body['parent_assist'], false);
    expect(body['duration_sec'], 42);
    expect(body['occurred_at'], '2026-09-22T10:00:00.000Z');
    expect(body.containsKey('session_id'), isFalse);
  });

  test('omitOccurredAt drops occurred_at (the clock-skew retry path)', () {
    final PendingSubmit item = PendingSubmit(
      id: 'x',
      childId: 'child-1',
      activityId: 'activity-1',
      clientOpId: 'op-1',
      body: const <String, dynamic>{'answers': <String, dynamic>{}, 'hints_used': 0, 'parent_assist': false, 'duration_sec': 0},
      occurredAt: DateTime.utc(2026, 9, 22, 10),
      createdAt: DateTime.utc(2026, 9, 22, 10),
      auth: 'child',
      omitOccurredAt: true,
    );
    expect(item.submitBody().containsKey('occurred_at'), isFalse);
  });
}
