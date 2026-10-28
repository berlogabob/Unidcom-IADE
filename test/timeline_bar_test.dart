import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/timeline.dart' as timeline;
import 'package:unidcom_iade/widgets/timeline_bar.dart';

// E3.2b (Rui 25 Sep, Overview B2·4): dated timeline replaces the 1-2-3 progress.
void main() {
  testWidgets('four labelled steps, dates as d Mon yyyy, current step marked', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineBar(
            record: timeline.ProfileRecord(
              live: const timeline.TimelineStep(
                'Not on the website yet',
                timeline.StepTone.todo,
              ),
              round: [
                timeline.TimelineStep(
                  'Draft',
                  timeline.StepTone.done,
                  DateTime.utc(2026, 8, 4),
                ),
                timeline.TimelineStep(
                  'Submitted',
                  timeline.StepTone.done,
                  DateTime.utc(2026, 9, 29),
                ),
                const timeline.TimelineStep(
                  'Under review',
                  timeline.StepTone.unidcom,
                  null,
                  "UNIDCOM's turn · reviewing",
                ),
                const timeline.TimelineStep('Approved', timeline.StepTone.todo),
              ],
            ),
          ),
        ),
      ),
    );
    for (final label in ['Draft', 'Submitted', 'Under review', 'Approved']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('4 Aug 2026'), findsOneWidget);
    expect(find.text('29 Sep 2026'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline-step-current')),
        matching: find.text('Under review'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel("Under review, UNIDCOM's turn · reviewing, —"),
      findsOneWidget,
    );
  });
}
