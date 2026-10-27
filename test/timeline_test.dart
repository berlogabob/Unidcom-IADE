import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/timeline.dart';
import 'package:unidcom_iade/theme/tokens.dart';
import 'package:unidcom_iade/widgets/timeline_bar.dart';

// "Your record" (1 Oct): the live version and the current round are separate,
// because the profile loops. Input is the my_profile_timeline() RPC payload.
Map<String, dynamic> t({
  String status = 'to_validate',
  bool visible = false,
  String round = '2026-09-29T15:49:00Z',
  String? submitted,
  String? review,
  String? approved,
  String? note,
}) => {
  'profile_status': status,
  'public_visibility': visible,
  'created_at': '2026-07-22T10:00:00Z',
  'round_started_at': round,
  'submitted_at': submitted,
  'review_started_at': review,
  'approved_at': approved,
  'review_note': note,
};

List<String> tones(ProfileRecord r) =>
    r.round!.map((s) => '${s.label}:${s.tone.name}').toList();

Future<void> pump(WidgetTester tester, ProfileRecord record) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimelineBar(record: record)),
      ),
    );

void main() {
  // Andrey, 1 Oct: approved 5 Aug, back to draft 29 Sep, submitted and taken
  // into review 1 Oct. The old line showed "Draft 22 Jul" and a dateless
  // green "Published" next to "Under review".
  final andrey = t(
    status: 'under_review',
    visible: true,
    submitted: '2026-10-01T13:41:06Z',
    review: '2026-10-01T13:57:40Z',
    approved: '2026-08-05T14:03:13Z',
  );

  test('a looped profile: live version from 5 Aug, round from 29 Sep', () {
    final r = profileRecord(andrey);
    expect(r.live.tone, StepTone.done);
    expect(r.live.date, DateTime.utc(2026, 8, 5, 14, 3, 13));
    expect(tones(r), [
      'Draft:done',
      'Submitted:done',
      'Under review:unidcom',
      'Approved:todo',
    ]);
    expect(r.round!.map((s) => s.date?.day), [29, 1, 1, null]);
  });

  test('dates from an older round never show on this one', () {
    final r = profileRecord(
      t(submitted: '2026-08-05T14:03:12Z', approved: '2026-08-05T14:03:13Z'),
    );
    expect(r.round![1].date, isNull);
    expect(r.round!.first.tone, StepTone.yours);
  });

  test('first draft: not on the website, your turn', () {
    final r = profileRecord(t(round: '2026-07-22T10:00:00Z'));
    expect(r.live.tone, StepTone.todo);
    expect(r.round!.first.status, 'Your turn · check and submit');
  });

  test('a returned profile is red: UNIDCOM asked for changes', () {
    final r = profileRecord(t(status: 'draft', note: 'Shorten the bio'));
    expect(r.round!.first.tone, StepTone.changes);
    expect(r.round!.first.status, 'UNIDCOM asked for changes');
  });

  test('submitted: UNIDCOM\'s turn', () {
    final r = profileRecord(
      t(status: 'pending_review', submitted: '2026-10-01T10:00:00Z'),
    );
    expect(r.round![1].tone, StepTone.unidcom);
    expect(r.round![1].status, "UNIDCOM's turn");
  });

  test('approved and public: no round', () {
    final r = profileRecord(
      t(status: 'approved', visible: true, approved: '2026-10-02T10:00:00Z'),
    );
    expect(r.round, isNull);
    expect(r.live.tone, StepTone.done);
  });

  test('approved, not public yet: UNIDCOM publishes', () {
    final r = profileRecord(t(status: 'approved'));
    expect(r.round, isNull);
    expect(r.live.tone, StepTone.unidcom);
  });

  testWidgets('live line and round render with dates and tone colours', (
    tester,
  ) async {
    await pump(tester, profileRecord(andrey));
    expect(
      find.text('Live on the website · Version approved 5 Aug 2026'),
      findsOneWidget,
    );
    expect(
      find.text('Changes in progress · started 29 Sep 2026'),
      findsOneWidget,
    );
    expect(find.text('29 Sep 2026'), findsOneWidget);
    expect(find.text('1 Oct 2026'), findsNWidgets(2));
    final current = tester.widget<Container>(
      find.ancestor(
        of: find.text('Under review'),
        matching: find.byKey(const ValueKey('timeline-step-current')),
      ),
    );
    expect((current.decoration as BoxDecoration).color, AppColors.blueTint);
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
  });

  testWidgets('nothing pending: one line', (tester) async {
    await pump(
      tester,
      profileRecord(
        t(status: 'approved', visible: true, approved: '2026-10-02T10:00:00Z'),
      ),
    );
    expect(
      find.text(
        'Live on the website · Version approved 2 Oct 2026 · No pending changes',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Changes in progress'), findsNothing);
  });
}
