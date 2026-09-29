import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/timeline.dart';

// E3.2 (Rui 25 Sep, Overview B2·4 + A3·8): Draft → Submitted → Under review →
// Published, with dates. Input is the my_profile_timeline() RPC payload.
Map<String, dynamic> t({
  String status = 'to_validate',
  bool visible = false,
  String? submitted,
  String? approved,
  String? published,
}) => {
  'profile_status': status,
  'public_visibility': visible,
  'created_at': '2026-08-04T10:00:00Z',
  'submitted_at': submitted,
  'approved_at': approved,
  'published_at': published,
};

List<String> states(List<TimelineStep> steps) =>
    steps.map((s) => '${s.label}:${s.state.name}').toList();

void main() {
  test('four steps in order', () {
    expect(profileTimeline(t()).map((s) => s.label), [
      'Draft',
      'Submitted',
      'Under review',
      'Published',
    ]);
  });

  test('to validate: Draft is current and dated from creation', () {
    final steps = profileTimeline(t());
    expect(states(steps), [
      'Draft:current',
      'Submitted:todo',
      'Under review:todo',
      'Published:todo',
    ]);
    expect(steps.first.date, DateTime.utc(2026, 8, 4, 10));
  });

  test('submitted: Submitted done with its date, Under review current', () {
    final steps = profileTimeline(
      t(status: 'pending_review', submitted: '2026-09-29T12:00:00Z'),
    );
    expect(states(steps), [
      'Draft:done',
      'Submitted:done',
      'Under review:current',
      'Published:todo',
    ]);
    expect(steps[1].date, DateTime.utc(2026, 9, 29, 12));
  });

  test('approved, not published: review done on approval date', () {
    final steps = profileTimeline(
      t(
        status: 'approved',
        submitted: '2026-09-29T12:00:00Z',
        approved: '2026-09-30T09:00:00Z',
      ),
    );
    expect(states(steps), [
      'Draft:done',
      'Submitted:done',
      'Under review:done',
      'Published:current',
    ]);
    expect(steps[2].date, DateTime.utc(2026, 9, 30, 9));
  });

  test('published: all done, dated when known', () {
    final steps = profileTimeline(
      t(status: 'approved', visible: true, published: '2026-10-01T08:00:00Z'),
    );
    expect(states(steps).last, 'Published:done');
    expect(steps.last.date, DateTime.utc(2026, 10, 1, 8));
  });

  test('legacy: already on the site but still to validate', () {
    final steps = profileTimeline(t(visible: true));
    expect(states(steps), [
      'Draft:current',
      'Submitted:todo',
      'Under review:todo',
      'Published:done',
    ]);
    expect(steps.last.date, isNull);
  });
}
