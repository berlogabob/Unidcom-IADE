import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/status_line.dart';

void main() {
  group('StatusLine', () {
    testWidgets(
      'shows correct labels for to_validate status with published website',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: StatusLine(
              person: {
                'profile_status': 'to_validate',
                'public_visibility': true,
              },
            ),
          ),
        );

        // Wait for the widget to fully render
        await tester.pump();

        expect(
          find.text('UNIDCOM: To be validated by you · Website: Published'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows correct labels for pending_review status with unpublished website',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: StatusLine(
              person: {
                'profile_status': 'pending_review',
                'public_visibility': false,
              },
            ),
          ),
        );

        // Wait for the widget to fully render
        await tester.pump();

        expect(
          find.text('UNIDCOM: Submitted · Website: Not published'),
          findsOneWidget,
        );
      },
    );

    testWidgets('leads with name and researcher type (brief G-3)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatusLine(
            person: {
              'preferred_name': 'Ana Nolasco',
              'membership_type': 'integrated',
              'profile_status': 'under_review',
              'public_visibility': false,
            },
          ),
        ),
      );
      expect(
        find.text('Ana Nolasco · Integrated researcher  ·  UNIDCOM: Under review · Website: Not published'),
        findsOneWidget,
      );
    });
  });
}
