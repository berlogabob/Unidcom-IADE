import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/researcher_home.dart';
import 'package:unidcom_iade/app/v1/overview_view.dart';

void main() {
  for (final v1 in [true, false]) {
    for (final status in [
      'pending',
      'submitted',
      'pending_review',
      'under_review',
    ]) {
      testWidgets('overview v1=$v1 counts $status outputs waiting for review', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final outputs = <Map<String, dynamic>>[
          {'id': 'o1', 'approval_status': status},
          {'id': 'o2', 'approval_status': status},
          {
            'id': 'o3',
            'approval_status': status,
            'website_status': 'published',
          },
          {'id': 'o4', 'approval_status': 'approved'},
        ];
        const person = <String, dynamic>{'profile_status': 'approved'};
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 2000,
                child: v1
                    ? OverviewView(
                        person: person,
                        alerts: const [],
                        timeline: null,
                        outputs: outputs,
                        featuredCount: 0,
                        onNavigate: (_) {},
                      )
                    : OverviewAlerts(
                        person: person,
                        requests: const [],
                        outputs: outputs,
                      ),
              ),
            ),
          ),
        );
        expect(find.text('2 outputs waiting for review'), findsOneWidget);
        expect(find.textContaining('No action required'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
