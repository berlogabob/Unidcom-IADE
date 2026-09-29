import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/orcid_block.dart';

// E4.2 (Rui 25 Sep, My Profile B3·3 + A3·3): import only, never "Sync".
Future<void> pump(WidgetTester tester, OrcidBlock block) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: block)),
);

void main() {
  testWidgets('connected: last import date, import action, the ORCID-untouched notice', (
    tester,
  ) async {
    var imported = 0;
    await pump(
      tester,
      OrcidBlock(
        connected: true,
        lastImported: DateTime.utc(2026, 9, 21),
        onImport: () => imported++,
        onConnect: () {},
      ),
    );
    expect(find.text('ORCID connected · Last imported 21 Sep 2026'), findsOneWidget);
    expect(find.text('Editing here does not change your ORCID record.'), findsOneWidget);
    await tester.tap(find.text('Import from ORCID'));
    expect(imported, 1);
    expect(find.textContaining('Sync'), findsNothing);
  });

  testWidgets('connected, never imported', (tester) async {
    await pump(
      tester,
      OrcidBlock(connected: true, onImport: () {}, onConnect: () {}),
    );
    expect(find.text('ORCID connected · Not imported yet'), findsOneWidget);
  });

  testWidgets('not connected: one Connect ORCID button, no import', (tester) async {
    var connected = 0;
    await pump(
      tester,
      OrcidBlock(connected: false, onImport: () {}, onConnect: () => connected++),
    );
    expect(find.text('ORCID not connected'), findsOneWidget);
    expect(find.text('Import from ORCID'), findsNothing);
    await tester.tap(find.text('Connect ORCID'));
    expect(connected, 1);
  });

  testWidgets('importing disables the button', (tester) async {
    await pump(
      tester,
      OrcidBlock(connected: true, busy: true, onImport: () {}, onConnect: () {}),
    );
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  });
}
