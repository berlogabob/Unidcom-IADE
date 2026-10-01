import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/suggestion_tile.dart';

Future<void> pumpTile(WidgetTester tester, Map<String, dynamic> s) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestionTile(
            suggestion: s,
            showTitle: false,
            onAccept: () {},
            onReject: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('a researcher edit says who and when, no percentage', (
    tester,
  ) async {
    await pumpTile(tester, {
      'field': 'bio',
      'current_value': 'Old bio',
      'suggested_value': 'New bio',
      'source': 'researcher',
      'confidence': 1,
      'created_at': '2026-10-01T13:41:06Z',
    });
    expect(find.text('Bio'), findsOneWidget);
    expect(
      find.text('Proposed by the researcher · 1 Oct 2026'),
      findsOneWidget,
    );
    expect(find.text('Now: Old bio'), findsOneWidget);
    expect(find.text('Proposed: New bio'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('an ORCID match shows its confidence', (tester) async {
    await pumpTile(tester, {
      'field': 'orcid',
      'current_value': null,
      'suggested_value': '0000-0002-1994-3944',
      'source': 'orcid',
      'confidence': 0.4,
      'created_at': '2026-07-22T11:25:24Z',
    });
    expect(find.text('ORCID'), findsOneWidget);
    expect(
      find.text('Found on ORCID · 40% match · 22 Jul 2026'),
      findsOneWidget,
    );
    expect(find.text('Now: empty'), findsOneWidget);
  });
}
