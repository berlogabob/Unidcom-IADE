import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/status_strip.dart';

void main() {
  Widget app(Map<String, dynamic> person, int pendingCandidates) => MaterialApp(
    home: Scaffold(
      body: StatusStrip(person: person, pendingCandidates: pendingCandidates),
    ),
  );

  testWidgets('shows disconnected draft profile', (tester) async {
    await tester.pumpWidget(app({'profile_status': 'draft'}, 0));
    expect(find.text('ORCID · Not connected'), findsOneWidget);
    expect(find.text('UNIDCOM · Profile not confirmed'), findsOneWidget);
    expect(find.text('Website · Not published'), findsOneWidget);
  });

  testWidgets('shows pending ORCID changes and published profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      app({
        'orcid': '0000-0001-2345-6789',
        'profile_status': 'approved',
        'public_visibility': true,
      }, 2),
    );
    expect(find.text('ORCID · Changes available'), findsOneWidget);
    expect(find.text('UNIDCOM · Approved'), findsOneWidget);
    expect(find.text('Website · Published'), findsOneWidget);
  });

  testWidgets('shows connected ORCID without changes', (tester) async {
    await tester.pumpWidget(
      app({'orcid': '0000-0001-2345-6789', 'profile_status': 'draft'}, 0),
    );
    expect(find.text('ORCID · Connected'), findsOneWidget);
  });
}
