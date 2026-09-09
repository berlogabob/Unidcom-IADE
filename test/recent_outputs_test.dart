import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/researcher_home.dart';

void main() {
  testWidgets('More reveals the rest in place', (tester) async {
    final outputs = [
      for (var i = 0; i < 5; i++)
        {'id': '$i', 'title': 'Paper $i', 'reporting_year': 2025},
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecentOutputs(outputs: outputs)),
      ),
    );
    expect(find.textContaining('Paper '), findsNWidgets(3));
    await tester.tap(find.text('More'));
    await tester.pump();
    expect(find.textContaining('Paper '), findsNWidgets(5));
    expect(find.text('More'), findsNothing);
  });
  testWidgets('three or fewer papers show no More button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentOutputs(
            outputs: [
              {'id': '1', 'title': 'Only one', 'reporting_year': 2025},
            ],
          ),
        ),
      ),
    );
    expect(find.text('More'), findsNothing);
  });

  testWidgets('Overview shows a human-readable pending profile status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewStats(
            person: {'profile_status': 'pending_review'},
            data: (
              person: {'profile_status': 'pending_review'},
              outputs: const [],
              requests: const [],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Awaiting UNIDCOM approval'), findsOneWidget);
    expect(find.text('pending_review'), findsNothing);
  });
}
