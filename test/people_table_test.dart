import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/people_table.dart';

// Rui's v1.0 brief PE-1: a table of researchers — name, type, ORCID linked,
// last login, issues, UNIDCOM status, Website status. A row opens the person.
final people = [
  {
    'id': 'p1',
    'preferred_name': 'Ana Nolasco',
    'membership_type': 'integrated',
    'orcid': '0000-0002-1234-5678',
    'profile_status': 'under_review',
    'public_visibility': true,
  },
  {
    'id': 'p2',
    'preferred_name': 'Rui Silva',
    'membership_type': 'collaborator',
    'orcid': null,
    'profile_status': 'to_validate',
    'public_visibility': false,
  },
];

Future<List<String>> pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final opened = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PeopleTable(
        people: people,
        lastSignIn: {'p1': DateTime(2026, 9, 28)},
        issues: const {'p2': 3},
        onOpen: opened.add,
      ),
    ),
  ));
  return opened;
}

void main() {
  testWidgets('seven columns in the brief\'s order', (tester) async {
    await pump(tester);
    final headers = [
      'Name', 'Type', 'ORCID', 'Last login', 'Issues', 'UNIDCOM status', 'Website',
    ];
    final xs = [for (final h in headers) tester.getTopLeft(find.text(h)).dx];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i] > xs[i - 1], isTrue, reason: headers[i]);
    }
  });

  testWidgets('cells read in words', (tester) async {
    await pump(tester);
    expect(find.text('Integrated'), findsOneWidget);
    expect(find.text('Collaborator'), findsOneWidget);
    expect(find.text('Linked'), findsOneWidget);
    expect(find.text('Not linked'), findsOneWidget);
    expect(find.text('28 Sep 2026'), findsOneWidget);
    expect(find.text('Never'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.text('To be validated'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Not published'), findsOneWidget);
  });

  testWidgets('tapping a row opens that person', (tester) async {
    final opened = await pump(tester);
    await tester.tap(find.text('Rui Silva'));
    expect(opened, ['p2']);
  });

  testWidgets('fits a phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PeopleTable(
          people: people,
          lastSignIn: const {},
          issues: const {},
          onOpen: (_) {},
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
