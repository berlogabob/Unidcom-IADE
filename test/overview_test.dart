import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/researcher_home.dart';

void main() {
  testWidgets('attention panel renders only its three actionable rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewAlerts(
            person: const {'profile_status': 'draft'},
            requests: const [],
            outputs: const [
              {'approval_status': 'rejected', 'error_count': 0},
            ],
            candidates: const [
              {'status': 'pending', 'matched_output_id': null},
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ListTile), findsNWidgets(3));
    expect(
      find.text('Your profile is not confirmed yet → Confirm it'),
      findsOneWidget,
    );
    expect(find.text('1 ORCID publication needs your review'), findsOneWidget);
    expect(
      find.text('1 output needs changes (UNIDCOM feedback)'),
      findsOneWidget,
    );
    expect(find.textContaining('No action required'), findsNothing);
  });

  testWidgets('output summary renders type counts and featured count', (
    tester,
  ) async {
    final outputs = [
      for (var i = 0; i < 4; i++)
        {'id': '$i', 'category_path': 'Research › Article'},
      for (var i = 4; i < 6; i++)
        {'id': '$i', 'category_path': 'Design › Exhibition'},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OutputSummary(outputs: outputs, featured: 2)),
      ),
    );

    expect(find.text('Scientific Outputs · 6'), findsOneWidget);
    expect(find.text('RESEARCH'), findsOneWidget);
    expect(find.text('DESIGN'), findsOneWidget);
    expect(find.text('FEATURED OUTPUTS'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
  });
}
