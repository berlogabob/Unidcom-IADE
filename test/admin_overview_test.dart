import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/admin_stats.dart';
import 'package:unidcom_iade/widgets/admin_overview.dart';

// E6.4 (Rui 25 Sep, Admin B1): numbers only, no bars; ORCID + Website sync
// block; issues without "Not approved yet"; outputs by type with year tabs;
// critical alerts open the researcher.
const stats = AdminStats(
  integrated: 28,
  collaborators: 14,
  profilesToApprove: 4,
  outputsToApprove: 3,
  orcidLinked: 30,
  orcidNotLinked: 12,
  sitePublished: 24,
  siteApprovedNotPublished: 5,
  siteNotPublished: 13,
  missingDoi: 7,
  notOnOrcid: 9,
  outputsByType: {'Livros': 18, 'Artigos em revistas': 10},
  outputsTotal: 28,
);

Future<List<String>> pump(
  WidgetTester tester, {
  int? year,
  List<({String text, String route})> alerts = const [],
  ValueChanged<int?>? onYear,
}) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final opened = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminOverview(
            stats: stats,
            years: const [2026, 2025, 2024],
            year: year,
            onYear: onYear ?? (_) {},
            activity: (lastMonth: 11, lastWeek: 4, never: 20),
            alerts: alerts,
            onOpenAlert: opened.add,
            onOpenProfilesToApprove: () => opened.add('profiles'),
            onOpenOutputsToApprove: () => opened.add('outputs'),
          ),
        ),
      ),
    ),
  );
  return opened;
}

void main() {
  testWidgets('four headline tiles', (tester) async {
    await pump(tester);
    expect(find.text('Integrated researchers'), findsOneWidget);
    expect(find.text('Collaborators'), findsOneWidget);
    expect(find.text('Profiles to approve'), findsOneWidget);
    expect(find.text('Outputs to approve'), findsOneWidget);
    expect(find.text('28'), findsWidgets);
    expect(find.text('14'), findsOneWidget);
    // Brief AD-2: exactly four tiles — proposals are alerts, not a tile.
    expect(find.text('Proposals to review'), findsNothing);
  });

  testWidgets('each approve tile opens its own tab', (tester) async {
    final opened = await pump(tester);
    await tester.tap(find.text('Profiles to approve'));
    await tester.tap(find.text('Outputs to approve'));
    expect(opened, ['profiles', 'outputs']);
  });

  testWidgets('sync status has an ORCID line and a Website line', (tester) async {
    await pump(tester);
    expect(find.text('ORCID: 30 linked · 12 not linked'), findsOneWidget);
    expect(
      find.text('Website: 24 published · 5 approved, not published · 13 not published'),
      findsOneWidget,
    );
  });

  testWidgets('issues are real issues only', (tester) async {
    await pump(tester);
    expect(find.text('Missing DOI · 7'), findsOneWidget);
    expect(find.text('Not on ORCID · 9'), findsOneWidget);
    expect(find.textContaining('Not approved yet'), findsNothing);
  });

  testWidgets('outputs by type as numbers with year chips', (tester) async {
    int? picked = -1;
    await pump(tester, onYear: (y) => picked = y);
    expect(find.text('Total · 28'), findsOneWidget);
    expect(find.text('Livros · 18'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('2025'));
    expect(picked, 2025);
    await tester.tap(find.text('All'));
    expect(picked, null);
  });

  testWidgets('researcher activity numbers', (tester) async {
    await pump(tester);
    expect(find.text('Logged in last month · 11'), findsOneWidget);
    expect(find.text('Active last week · 4'), findsOneWidget);
    expect(find.text('Never logged in · 20'), findsOneWidget);
    expect(find.text('low priority'), findsNothing);
  });

  testWidgets('a critical alert names the researcher and opens its target', (tester) async {
    final opened = await pump(
      tester,
      alerts: [
        (text: 'Andrey Dyakov proposed a Bio change', route: '/app/admin/review?tab=suggestions'),
        (text: 'Ana Nolasco — no ORCID linked', route: '/people/p1'),
      ],
    );
    await tester.tap(find.text('Andrey Dyakov proposed a Bio change'));
    await tester.tap(find.text('Ana Nolasco — no ORCID linked'));
    expect(opened, ['/app/admin/review?tab=suggestions', '/people/p1']);
  });
}
