import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeschooling/features/player/step_views/single_choice_step_view.dart';
import 'package:homeschooling/models/steps.dart';

void main() {
  final SingleChoiceStep step = SingleChoiceStep(
    id: 's3',
    prompt: 'What did the boy plant?',
    options: const <Choice>[Choice('o1', 'A seed'), Choice('o2', 'A shoe'), Choice('o3', 'A ball')],
  );

  Widget host({String? answer, required ValueChanged<String> onChanged}) {
    return MaterialApp(
      home: Scaffold(body: SingleChoiceStepView(step: step, answer: answer, onChanged: onChanged)),
    );
  }

  testWidgets('shows the prompt and every option label', (WidgetTester tester) async {
    await tester.pumpWidget(host(onChanged: (String _) {}));

    expect(find.text('What did the boy plant?'), findsOneWidget);
    expect(find.text('A seed'), findsOneWidget);
    expect(find.text('A shoe'), findsOneWidget);
    expect(find.text('A ball'), findsOneWidget);
  });

  testWidgets('tapping an option reports its id, not its label', (WidgetTester tester) async {
    String? picked;
    await tester.pumpWidget(host(onChanged: (String id) => picked = id));

    await tester.tap(find.text('A shoe'));
    await tester.pump();

    expect(picked, 'o2');
  });

  testWidgets('the currently selected option is visually distinct', (WidgetTester tester) async {
    await tester.pumpWidget(host(answer: 'o1', onChanged: (String _) {}));

    final OutlinedButton selected = tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('A seed'), matching: find.byType(OutlinedButton)),
    );
    final OutlinedButton unselected = tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('A shoe'), matching: find.byType(OutlinedButton)),
    );
    final Color? selectedColor = selected.style?.backgroundColor?.resolve(<WidgetState>{});
    final Color? unselectedColor = unselected.style?.backgroundColor?.resolve(<WidgetState>{});
    expect(selectedColor, isNotNull);
    expect(selectedColor, isNot(unselectedColor));
  });
}
