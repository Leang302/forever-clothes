import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/auth/presentation/widgets/otp_input.dart';

void main() {
  testWidgets('shows typed digits in boxes and reports the completed code', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final completed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpInput(controller: controller, onCompleted: completed.add),
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), '123');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(completed, isEmpty);

    await tester.enterText(find.byType(EditableText), '123456');
    await tester.pump();
    expect(completed, ['123456']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores non-digits and extra characters', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtpInput(controller: controller)),
      ),
    );

    await tester.enterText(find.byType(EditableText), '12ab34567890');
    await tester.pump();
    expect(controller.text, '123456');
  });
}
