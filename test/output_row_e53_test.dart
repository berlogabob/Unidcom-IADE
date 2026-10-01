import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/public/person/output_row.dart';

// E5.3 (Rui 25 Sep, A4·7, A4·8, B4·6) and the v1.0 brief SO-6: one row —
// type · subtype tag, title, year underneath, every issue in full, star.
Map<String, dynamic> author({
  String type = 'Artigos em revistas',
  String? subtype = 'Artigo',
  String source = 'manual',
  List<String> codes = const [],
  String affiliation = 'unidcom',
}) => {
  'role': 'Autor',
  'outputs': {
    'id': 'o1',
    'title': 'A Study',
    'reporting_year': 2025,
    'type': type,
    'subtype': subtype,
    'source': source,
    'approval_status': 'to_validate',
    'website_status': 'published',
    'issue_codes': codes,
    'affiliation': affiliation,
    'error_count': 0,
    'warning_count': codes.length,
  },
};

Future<void> pumpRow(
  WidgetTester tester,
  Map<String, dynamic> a, {
  bool featurable = true,
}) async {
  tester.view.physicalSize = const Size(1400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PersonOutputRow(
          author: a,
          isFeatured: false,
          onTap: (_) {},
          onToggle: (_) {},
          showStates: true,
          featurable: featurable,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the tag reads Type · Subtype', (tester) async {
    await pumpRow(tester, author());
    expect(find.text('ARTIGOS EM REVISTAS · ARTIGO'), findsOneWidget);
  });

  testWidgets('every issue is written in full, never "+N"', (tester) async {
    await pumpRow(tester, author(source: 'orcid', codes: ['missing_doi', 'missing_year']));
    expect(find.text('Missing DOI · Missing year'), findsOneWidget);
    expect(find.textContaining('+1'), findsNothing);
  });

  testWidgets('no issues says so', (tester) async {
    await pumpRow(tester, author(source: 'orcid'));
    expect(find.text('No issues'), findsOneWidget);
  });

  testWidgets('a publication missing from ORCID names it as an issue', (tester) async {
    await pumpRow(tester, author(codes: ['missing_doi']));
    expect(find.text('Missing DOI · Not on ORCID'), findsOneWidget);
    await pumpRow(tester, author());
    expect(find.text('Not on ORCID'), findsOneWidget);
  });

  testWidgets('an activity is never "Not on ORCID"', (tester) async {
    await pumpRow(tester, author(), featurable: false);
    expect(find.text('No issues'), findsOneWidget);
    expect(find.textContaining('ORCID'), findsNothing);
  });

  testWidgets('no ORCID or Website pills; year underneath, no role or DOI', (tester) async {
    await pumpRow(tester, author(source: 'orcid'));
    expect(find.text('On ORCID'), findsNothing);
    expect(find.textContaining('Website ·'), findsNothing);
    expect(find.text('2025'), findsOneWidget);
    expect(find.textContaining('Autor'), findsNothing);
  });

  testWidgets('only featurable rows (publications) get a star', (tester) async {
    await pumpRow(tester, author(), featurable: false);
    expect(find.byIcon(Icons.star_border), findsNothing);
    await pumpRow(tester, author(), featurable: true);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  testWidgets('work outside UNIDCOM shows, tagged, and is never featured', (tester) async {
    await pumpRow(tester, author(source: 'orcid', affiliation: 'external'));
    expect(find.text('Outside UNIDCOM'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNothing);
    await pumpRow(tester, author(source: 'orcid'));
    expect(find.text('Outside UNIDCOM'), findsNothing);
  });
}
