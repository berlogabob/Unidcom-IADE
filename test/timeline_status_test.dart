import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/timeline.dart';
import 'package:unidcom_iade/theme/tokens.dart';
import 'package:unidcom_iade/widgets/timeline_bar.dart';

// Rui's v1.0 brief OV-2: each step shows a dot, its name, a short status line
// and the date; completed steps have a check, the current step is highlighted,
// future steps are grey.
Map<String, dynamic> row(String status, {bool visible = false, String? note}) =>
    {
      'profile_status': status,
      'public_visibility': visible,
      'created_at': '2026-09-01T10:00:00Z',
      'submitted_at': '2026-09-10T10:00:00Z',
      'review_note': note,
    };

void main() {
  test('each step carries a short status line', () {
    final draft = profileRecord(row('to_validate')).round!;
    expect(draft.map((s) => s.status), [
      'Your turn · check and submit',
      'Not yet',
      'Not yet',
      'Not yet',
    ]);
    final review = profileRecord(row('under_review')).round!;
    expect(review.map((s) => s.status), [
      'Done',
      'Done',
      "UNIDCOM's turn · reviewing",
      'Not yet',
    ]);
    expect(
      profileRecord(row('pending_review')).round![1].status,
      "UNIDCOM's turn",
    );
    final approved = profileRecord(row('approved'));
    expect(approved.round, isNull);
    expect(approved.live.label, 'Approved');
    expect(approved.live.status, 'UNIDCOM publishes it');
    final published = profileRecord(row('approved', visible: true));
    expect(published.round, isNull);
    expect(published.live.label, 'Live on the website');
    expect(published.live.status, 'Published');
  });

  test('a returned profile says UNIDCOM asked for changes', () {
    final steps = profileRecord(
      row('draft', note: 'Please shorten the bio'),
    ).round!;
    expect(steps.first.status, 'UNIDCOM asked for changes');
  });

  testWidgets('current step is highlighted; future steps are grey', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineBar(record: profileRecord(row('pending_review'))),
        ),
      ),
    );
    expect(find.text("UNIDCOM's turn"), findsOneWidget);
    final current = tester.widget<Container>(
      find.ancestor(
        of: find.text('Submitted'),
        matching: find.byKey(const ValueKey('timeline-step-current')),
      ),
    );
    expect((current.decoration as BoxDecoration).color, AppColors.blueTint);
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // Draft done
    final future = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('timeline-step-Approved')),
        matching: find.byType(Icon),
      ),
    );
    expect(future.color, AppColors.textMuted);
  });
}
