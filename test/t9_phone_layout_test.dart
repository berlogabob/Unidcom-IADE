import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/dashboard.dart';
import 'package:unidcom_iade/widgets/panels.dart';

void main() {
  testWidgets('dashboard KPI tiles fit a phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardKpiTiles(
            tiles: [
              for (final label in [
                'ORCID LINKED',
                'PROFILES VALIDATED',
                'OUTPUTS APPROVED',
                'DOI COVERAGE',
              ])
                AccentStatCard(label: label, value: '1 / 1'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ORCID LINKED'), findsOneWidget);
    expect(find.text('PROFILES VALIDATED'), findsOneWidget);
    expect(find.text('OUTPUTS APPROVED'), findsOneWidget);
    expect(find.text('DOI COVERAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
