import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeschooling/features/common/pin_pad.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('submit is disabled until minLength digits are entered', (WidgetTester tester) async {
    String? submitted;
    await tester.pumpWidget(
      host(
        PinPad(
          minLength: 4,
          onSubmit: (String pin) async {
            submitted = pin;
          },
        ),
      ),
    );

    final Finder confirmButton = find.widgetWithText(FilledButton, 'Confirm');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    for (final String digit in <String>['1', '2', '3']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.tap(find.text('4'));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(submitted, '1234');
  });

  testWidgets('backspace removes the last digit', (WidgetTester tester) async {
    await tester.pumpWidget(host(PinPad(onSubmit: (String _) async {})));

    await tester.tap(find.text('5'));
    await tester.tap(find.text('6'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    // Only 1 digit remains (below minLength 4), so Confirm is still disabled.
    final Finder confirmButton = find.widgetWithText(FilledButton, 'Confirm');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
  });

  testWidgets('an errorText clears the entered digits', (WidgetTester tester) async {
    await tester.pumpWidget(host(PinPad(onSubmit: (String _) async {})));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('4'));
    await tester.pump();

    await tester.pumpWidget(host(PinPad(onSubmit: (String _) async {}, errorText: 'Wrong PIN')));
    await tester.pump();

    expect(find.text('Wrong PIN'), findsOneWidget);
    final Finder confirmButton = find.widgetWithText(FilledButton, 'Confirm');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
  });
}
