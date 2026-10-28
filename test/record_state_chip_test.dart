import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/record_state.dart';
import 'package:unidcom_iade/public/person/output_row.dart';
import 'package:unidcom_iade/widgets/output_row.dart';
import 'package:unidcom_iade/widgets/panels.dart';
import 'package:unidcom_iade/widgets/people_table.dart';
import 'package:unidcom_iade/widgets/record_state_chip.dart';

void main() {
  const cases = [
    ({'approval_status': 'draft'}, 'Draft'),
    ({'approval_status': 'pending'}, 'In review'),
    ({'approval_status': 'approved'}, 'Approved'),
    ({'approval_status': 'pending', 'website_status': 'published'}, 'On site'),
  ];
  for (final (record, label) in cases) {
    testWidgets('$label uses the same chip for people and output rows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PeopleTable(
                  people: [
                    {
                      'id': 'p1',
                      'profile_status': record['approval_status'],
                      'website_status': record['website_status'],
                    },
                  ],
                  lastSignIn: const {},
                  issues: const {},
                  onOpen: (_) {},
                ),
                OutputRow(title: 'Admin output', state: recordState(record)),
                PersonOutputRow(
                  author: {
                    'outputs': {'id': 'o1', ...record},
                  },
                  isFeatured: false,
                  onTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(RecordStateChip), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byType(StatusPill),
          matching: find.text(label),
        ),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
