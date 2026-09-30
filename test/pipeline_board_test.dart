import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/pipeline_board.dart';

// E6.6 (Rui 25 Sep, Admin A1·8) and the v1.0 brief PA-1: Draft → Submitted →
// Under review → Approved, not published → Published. Approve, Request changes
// and Reject act on Submitted and Under review; Publish lives only in Approved,
// not published.
final people = <Map<String, dynamic>>[
  {'id': 'a', 'preferred_name': 'Ana', 'profile_status': 'to_validate', 'public_visibility': false},
  {'id': 'b', 'preferred_name': 'Bruno', 'profile_status': 'pending_review', 'public_visibility': false},
  {'id': 'c', 'preferred_name': 'Carla', 'profile_status': 'approved', 'public_visibility': false},
  {'id': 'd', 'preferred_name': 'Duarte', 'profile_status': 'approved', 'public_visibility': true},
  {'id': 'e', 'preferred_name': 'Eva', 'profile_status': 'to_validate', 'public_visibility': true},
  {'id': 'f', 'preferred_name': 'Filipa', 'profile_status': 'draft', 'public_visibility': false, 'review_note': 'Shorten the bio'},
  {'id': 'g', 'preferred_name': 'Gil', 'profile_status': 'under_review', 'public_visibility': false},
];

void main() {
  test('columns in order, each person in exactly one', () {
    final cols = pipelineColumns(people);
    expect(cols.keys, [
      'Draft',
      'Submitted',
      'Under review',
      'Approved, not published',
      'Published',
    ]);
    List<String> ids(String k) => cols[k]!.map((p) => p['id'] as String).toList();
    expect(ids('Draft'), ['a', 'e', 'f']);
    expect(ids('Submitted'), ['b']);
    expect(ids('Under review'), ['g']);
    expect(ids('Approved, not published'), ['c']);
    expect(ids('Published'), ['d']);
  });

  testWidgets('Approve, Request changes and Reject on Submitted and Under review; Publish separate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PipelineBoard(
            people: people,
            onStartReview: (id) => calls.add('start:$id'),
            onApprove: (id) => calls.add('approve:$id'),
            onRequestChanges: (id) => calls.add('changes:$id'),
            onReject: (id) => calls.add('reject:$id'),
            onPublish: (id) => calls.add('publish:$id'),
            onUnpublish: (id) => calls.add('unpublish:$id'),
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Draft · 3'), findsOneWidget);
    expect(find.text('Submitted · 1'), findsOneWidget);
    expect(find.text('Under review · 1'), findsOneWidget);
    expect(find.text('Approved, not published · 1'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
    expect(find.text('Approve'), findsNWidgets(2));
    expect(find.text('Request changes'), findsNWidgets(2));
    expect(find.text('Reject'), findsNWidgets(2));
    expect(find.text('Publish to website'), findsOneWidget);
    expect(find.text('Unpublish'), findsOneWidget);
    expect(find.text('Changes requested: Shorten the bio'), findsOneWidget);
    await tester.tap(find.text('Start review'));
    await tester.tap(find.text('Approve').first);
    await tester.tap(find.text('Request changes').last);
    await tester.tap(find.text('Reject').first);
    await tester.tap(find.text('Publish to website'));
    expect(calls, ['start:b', 'approve:b', 'changes:g', 'reject:b', 'publish:c']);
  });
}
