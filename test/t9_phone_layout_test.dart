import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/dashboard.dart';
import 'package:unidcom_iade/app/reports.dart';
import 'package:unidcom_iade/app/review_queue.dart';
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
                'CIÊNCIA ID ON FILE',
                'UNCLAIMED ORCID CANDIDATES',
                'PUBLICATIONS MISSING DOI',
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
    expect(find.text('CIÊNCIA ID ON FILE'), findsOneWidget);
    expect(find.text('UNCLAIMED ORCID CANDIDATES'), findsOneWidget);
    expect(find.text('PUBLICATIONS MISSING DOI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('data quality tone warns only above 50% missing', () {
    expect(dataQualityTone(5, 10), AccentTone.neutral);
    expect(dataQualityTone(6, 10), AccentTone.warn);
    expect(dataQualityTone(1, 0), AccentTone.neutral);
  });

  testWidgets('review queue tabs fit a phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DefaultTabController(length: 7, child: ReviewQueueTabs()),
        ),
      ),
    );

    for (final label in [
      'Profiles to approve',
      'Outputs to approve',
      'Needs re-verification',
      'Suggestions',
      'Activity',
      'Needs attention',
      'ORCID works',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('report type cell truncates long labels without overflow', (
    tester,
  ) async {
    const label =
        'A category label that is deliberately long enough to exceed the report column width';
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReportTypeCell(label))),
    );

    final text = tester.widget<Text>(find.text(label));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(find.byTooltip(label), findsOneWidget);
    expect(tester.getSize(find.byType(SizedBox)).width, 220);
    expect(tester.takeException(), isNull);
  });
}
