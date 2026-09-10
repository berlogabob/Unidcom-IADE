import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/public/person/person_dialogs.dart';

Map<String, dynamic> person() => {
  'id': 'p1',
  'preferred_name': 'Ana',
  'legal_name': 'Ana Nolasco',
  'phone': 'old phone',
};

void main() {
  testWidgets('owner sees only profile fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPersonEditor(
                context,
                person: person(),
                canEditGovernance: false,
                stage: (_, _, _) async => 0,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Propose changes to my profile'), findsOneWidget);
    expect(find.text('Membership type'), findsNothing);
    expect(find.text('Status'), findsNothing);
    expect(find.text('Profile status'), findsNothing);
    expect(find.text('Public visibility'), findsNothing);
    expect(find.text('PhD'), findsNothing);
    expect(find.text('Submit for review'), findsOneWidget);
  });

  testWidgets('owner stages changes and never updates directly', (
    tester,
  ) async {
    Map<String, String?>? current;
    Map<String, String>? proposed;
    var updates = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPersonEditor(
                context,
                person: person(),
                canEditGovernance: false,
                stage: (_, gotCurrent, gotProposed) async {
                  current = gotCurrent;
                  proposed = gotProposed;
                  return 1;
                },
                update: (_, _) async => updates++,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Phone'), 'new phone');
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(proposed?['phone'], 'new phone');
    expect(current?['phone'], 'old phone');
    expect(updates, 0);
  });

  testWidgets('owner with no changes stays open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPersonEditor(
                context,
                person: person(),
                canEditGovernance: false,
                stage: (_, _, _) async => 0,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pump();

    expect(find.text('No changes'), findsOneWidget);
    expect(find.text('Propose changes to my profile'), findsOneWidget);
  });

  testWidgets('admin still has governance controls and Save', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPersonEditor(
                context,
                person: person(),
                stage: (_, _, _) async => 0,
                update: (_, _) async {},
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Membership type'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
