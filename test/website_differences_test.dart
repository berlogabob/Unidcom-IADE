import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/website_differences_view.dart';
import 'package:unidcom_iade/app/admin_page.dart';
import 'package:unidcom_iade/main.dart';

final issues = <WebsiteIssue>[
  {
    'kind': 'same',
    'entity': 'outputs',
    'key': 'o',
    'label': 'Paper',
    'fields': [],
  },
  {
    'kind': 'website_only',
    'entity': 'people',
    'key': 'w',
    'label': 'New person',
    'fields': [
      {'name': 'name', 'portal': null, 'website': 'New person'},
    ],
    'note': 'Review before adding; no import performed.',
  },
  {
    'kind': 'differs',
    'entity': 'people',
    'key': 'p',
    'label': 'Person',
    'fields': [
      {'name': 'email', 'portal': 'old', 'website': 'new'},
    ],
  },
];

void main() {
  test('comparison route is registered, authenticated and admin-only', () {
    const route = '/app/admin/website-differences';
    expect(adminTools, contains('website-differences'));
    expect(needsAuth(route), isTrue);
    expect(
      modeRedirect(route, adminAccount: false, adminMode: false, chosen: true),
      '/app/home',
    );
    expect(
      modeRedirect(route, adminAccount: true, adminMode: false, chosen: true),
      '/app/home',
    );
    expect(
      modeRedirect(route, adminAccount: true, adminMode: true, chosen: true),
      isNull,
    );
  });

  test('groups and filters by kind and entity in stable order', () {
    expect(groupWebsiteIssues(issues).keys, [
      'differs/people',
      'website_only/people',
      'same/outputs',
    ]);
    expect(groupWebsiteIssues(issues, kind: 'same', entity: 'people'), isEmpty);
    expect(groupWebsiteIssues(issues, entity: 'people').length, 2);
    expect(groupWebsiteIssues([], kind: 'differs'), isEmpty);
  });

  test(
    'CSV keeps same rows, notes, missing values and escapes unsafe cells',
    () {
      final csv = websiteIssuesCsv([
        ...issues,
        {
          'kind': 'portal_only',
          'entity': 'outputs',
          'key': 'csv',
          'label': '=SUM(1,2)',
          'fields': [
            {'name': 'citation', 'portal': 'A "quote",\nnext', 'website': null},
          ],
        },
      ]);
      expect(csv, contains('"same","outputs","o","Paper","","","",""'));
      expect(csv, contains('"Review before adding; no import performed."'));
      expect(csv, contains('"\'=SUM(1,2)"'));
      expect(csv, contains('"A ""quote"",\nnext"'));
    },
  );

  testWidgets(
    'shows groups, counts, field values, filters and exports visible rows',
    (tester) async {
      String? copied;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WebsiteDifferencesView(
                issues: issues,
                onCopy: (csv) async {
                  copied = csv;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('Differs (1)'), findsOneWidget);
      expect(find.text('Website only · people (1)'), findsOneWidget);
      await tester.tap(find.text('Person'));
      await tester.pumpAndSettle();
      expect(find.text('Portal: old\nWebsite: new'), findsOneWidget);
      await tester.tap(find.text('Website only (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Person'), findsNothing);
      expect(find.text('New person'), findsOneWidget);
      await tester.tap(find.text('Copy as CSV (1)'));
      await tester.pumpAndSettle();
      expect(copied, contains('website_only'));
      expect(copied, isNot(contains('"differs"')));
      await tester.tap(find.text('outputs (1)'));
      await tester.pumpAndSettle();
      expect(find.text('No records for these filters.'), findsOneWidget);
    },
  );
}
