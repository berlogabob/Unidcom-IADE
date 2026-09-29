import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/public/person/person_dialogs.dart';

// E4.6 (Rui 25 Sep, My Profile B3·2): "Save draft" and "Submit for UNIDCOM
// review". A draft never reaches the UNIDCOM queue.
void main() {
  Future<void> open(
    WidgetTester tester, {
    required Future<int> Function(String, Map<String, String?>, Map<String, String>) stage,
    required Future<int> Function(String, Map<String, String?>, Map<String, String>) stageDraft,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPersonEditor(
                context,
                person: const {'id': 'p1', 'preferred_name': 'Ana'},
                canEditGovernance: false,
                stage: stage,
                stageDraft: stageDraft,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  testWidgets('owner sees Save draft and Submit for UNIDCOM review', (tester) async {
    await open(tester, stage: (_, _, _) async => 0, stageDraft: (_, _, _) async => 0);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Submit for UNIDCOM review'), findsOneWidget);
  });

  testWidgets('Save draft stages as draft, never as a submission', (tester) async {
    var submitted = 0;
    Map<String, String>? drafted;
    await open(
      tester,
      stage: (_, _, _) async => ++submitted,
      stageDraft: (_, _, proposed) async {
        drafted = proposed;
        return 1;
      },
    );
    await tester.enterText(find.widgetWithText(TextField, 'Preferred name'), 'Ana N.');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(drafted?['preferred_name'], 'Ana N.');
    expect(submitted, 0);
    expect(find.text('Draft saved — not sent to UNIDCOM yet'), findsOneWidget);
  });
}
