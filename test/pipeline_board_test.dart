import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/pipeline_board.dart';

// E6.6 (Rui 25 Sep, Admin A1·8): stage pipeline on Pending approval, with an
// "Approved, not published" column; "Publish to website" separate from "Approve".
final people = <Map<String, dynamic>>[
  {'id': 'a', 'preferred_name': 'Ana', 'profile_status': 'to_validate', 'public_visibility': false},
  {'id': 'b', 'preferred_name': 'Bruno', 'profile_status': 'pending_review', 'public_visibility': false},
  {'id': 'c', 'preferred_name': 'Carla', 'profile_status': 'approved', 'public_visibility': false},
  {'id': 'd', 'preferred_name': 'Duarte', 'profile_status': 'approved', 'public_visibility': true},
  {'id': 'e', 'preferred_name': 'Eva', 'profile_status': 'to_validate', 'public_visibility': true},
  {'id': 'f', 'preferred_name': 'Filipa', 'profile_status': 'draft', 'public_visibility': false},
  {'id': 'g', 'preferred_name': 'Gil', 'profile_status': 'under_review', 'public_visibility': false},
];

void main() {
  test('columns in order, each person in exactly one', () {
    final cols = pipelineColumns(people);
    expect(cols.keys, [
      'To validate',
      'Submitted',
      'Under review',
      'Approved, not published',
      'Published',
    ]);
    List<String> ids(String k) => cols[k]!.map((p) => p['id'] as String).toList();
    expect(ids('To validate'), ['a', 'e', 'f']);
    expect(ids('Submitted'), ['b']);
    expect(ids('Under review'), ['g']);
    expect(ids('Approved, not published'), ['c']);
    expect(ids('Published'), ['d']);
  });

  testWidgets('Start review, Approve and Publish are separate actions in their own columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final approved = <String>[];
    final started = <String>[];
    final published = <String>[];
    final unpublished = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PipelineBoard(
            people: people,
            onStartReview: started.add,
            onApprove: approved.add,
            onPublish: published.add,
            onUnpublish: unpublished.add,
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Submitted · 1'), findsOneWidget);
    expect(find.text('Under review · 1'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
    expect(find.text('Approved, not published · 1'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Publish to website'), findsOneWidget);
    expect(find.text('Unpublish'), findsOneWidget);
    await tester.tap(find.text('Start review'));
    await tester.tap(find.text('Approve'));
    await tester.tap(find.text('Publish to website'));
    expect(started, ['b']);
    expect(approved, ['g']);
    expect(published, ['c']);
  });
}
