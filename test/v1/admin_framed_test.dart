import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/admin_stats.dart';
import 'package:unidcom_iade/widgets/admin_overview.dart';
import 'package:unidcom_iade/widgets/panels.dart';

// Admin B1 on the design system: every block of the dashboard is a Panel
// (5 tiles + sync + activity + issues + outputs by type + alerts = 10).
void main() {
  testWidgets('dashboard blocks are Panels', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminOverview(
              stats: const AdminStats(
                integrated: 1, collaborators: 1, profilesToApprove: 0, outputsToApprove: 0,
                orcidLinked: 1, orcidNotLinked: 1, sitePublished: 1, siteApprovedNotPublished: 0,
                siteNotPublished: 1, missingDoi: 0, notOnOrcid: 0,
                outputsByType: {'Livros': 1}, outputsTotal: 1,
              ),
              years: const [2025],
              onYear: (_) {},
              activity: (lastMonth: 0, lastWeek: 0, never: 1),
              onOpenPerson: (_) {},
              onOpenProfilesToApprove: () {},
              onOpenOutputsToApprove: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Panel), findsAtLeastNWidgets(10));
    expect(find.byType(Card), findsNothing);
  });
}
