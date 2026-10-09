import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/review_session.dart';

// Spec for the researcher review (brief RV-2, RV-6, RV-7). Decisions live in
// memory until Finish review; Undo is therefore client-side.
void main() {
  ReviewSession session() => ReviewSession([
    const ReviewItem(id: 'a', kind: ReviewKind.field),
    const ReviewItem(id: 'b', kind: ReviewKind.field),
    const ReviewItem(id: 'c', kind: ReviewKind.output),
  ]);

  test('counts decided items and blocks finish until all are decided', () {
    final s = session();
    expect(s.total, 3);
    expect(s.decided, 0);
    expect(s.canFinish, isFalse);
    s.decide('a', ReviewDecision.accepted);
    expect(s.decided, 1);
    expect(s.canFinish, isFalse);
  });

  test('request change needs a comment, reject and accept do not', () {
    final s = session();
    expect(
      () => s.decide('a', ReviewDecision.changeRequested, comment: '  '),
      throwsArgumentError,
    );
    s.decide('a', ReviewDecision.changeRequested, comment: 'Please add the DOI');
    s.decide('b', ReviewDecision.rejected);
    expect(s.decided, 2);
  });

  test('undo reopens an item', () {
    final s = session()..decide('a', ReviewDecision.accepted);
    s.undo('a');
    expect(s.decided, 0);
  });

  test('accept all remaining leaves earlier decisions untouched', () {
    final s = session()..decide('a', ReviewDecision.rejected);
    s.acceptAllRemaining();
    expect(s.canFinish, isTrue);
    expect(s.decisionOf('a'), ReviewDecision.rejected);
    expect(s.decisionOf('b'), ReviewDecision.accepted);
  });

  test('decided items sink below open ones, keeping original order', () {
    final s = session()..decide('a', ReviewDecision.accepted);
    expect(s.ordered.map((i) => i.id), ['b', 'c', 'a']);
  });

  test('payload matches finish_review and refuses an unfinished session', () {
    final s = session();
    expect(s.toPayload, throwsStateError);
    s.decide('a', ReviewDecision.accepted);
    s.decide('b', ReviewDecision.changeRequested, comment: 'Confirm the year');
    s.decide('c', ReviewDecision.rejected, comment: 'Duplicate');
    expect(s.toPayload(), [
      {'kind': 'field', 'id': 'a', 'decision': 'accepted', 'comment': null},
      {
        'kind': 'field',
        'id': 'b',
        'decision': 'change_requested',
        'comment': 'Confirm the year',
      },
      {'kind': 'output', 'id': 'c', 'decision': 'rejected', 'comment': 'Duplicate'},
    ]);
  });
}
