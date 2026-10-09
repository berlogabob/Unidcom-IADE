import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/timeline.dart';
import 'package:unidcom_iade/theme/tokens.dart';
import 'package:unidcom_iade/widgets/timeline_bar.dart';

// Rui's v1.0 brief OV-2: each step shows a dot, its name, a short status line
// and the date; completed steps have a check, the current step is highlighted,
// future steps are grey.
Map<String, dynamic> row(String status, {bool visible = false, String? note}) => {
  'profile_status': status,
  'public_visibility': visible,
  'created_at': '2026-09-01T10:00:00Z',
  'submitted_at': '2026-09-10T10:00:00Z',
  'review_note': note,
};

void main() {
  test('each step carries a short status line', () {
    final draft = profileTimeline(row('to_validate'));
    expect(draft.map((s) => s.status), [
      'Check your profile and submit',
      'Not yet',
      'Not yet',
      'Not yet',
    ]);
    final review = profileTimeline(row('under_review'));
    expect(review.map((s) => s.status), [
      'Done',
      'Done',
      'UNIDCOM is reviewing',
      'Not yet',
    ]);
    expect(profileTimeline(row('pending_review'))[1].status, 'Waiting for UNIDCOM');
    expect(profileTimeline(row('approved'))[3].status, 'Approved · UNIDCOM publishes');
    expect(profileTimeline(row('approved', visible: true))[3].status, 'On the website');
  });

  test('a returned profile says UNIDCOM asked for changes', () {
    final steps = profileTimeline(row('draft', note: 'Please shorten the bio'));
    expect(steps.first.status, 'UNIDCOM asked for changes');
  });

  testWidgets('current step is highlighted; future steps are grey', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TimelineBar(steps: profileTimeline(row('pending_review')))),
    ));
    expect(find.text('Waiting for UNIDCOM'), findsOneWidget);
    final current = tester.widget<Container>(find.ancestor(
      of: find.text('Submitted'),
      matching: find.byKey(const ValueKey('timeline-step-current')),
    ));
    expect((current.decoration as BoxDecoration).color, AppColors.tealTint);
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // Draft done
    final future = tester.widget<Icon>(find.descendant(
      of: find.byKey(const ValueKey('timeline-step-Published')),
      matching: find.byType(Icon),
    ));
    expect(future.color, AppColors.textMuted);
  });
}
