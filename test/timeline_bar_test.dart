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
            steps: [
              timeline.TimelineStep(
                'Draft',
                timeline.StepState.done,
                DateTime.utc(2026, 8, 4),
              ),
              timeline.TimelineStep(
                'Submitted',
                timeline.StepState.done,
                DateTime.utc(2026, 9, 29),
              ),
              timeline.TimelineStep('Under review', timeline.StepState.current),
              timeline.TimelineStep('Published', timeline.StepState.todo),
            ],
          ),
        ),
      ),
    );
    for (final label in ['Draft', 'Submitted', 'Under review', 'Published']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('4 Aug 2026'), findsOneWidget);
    expect(find.text('29 Sep 2026'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Under review, in progress')),
      findsOneWidget,
    );
  });
}
