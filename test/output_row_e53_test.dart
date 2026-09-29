import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/public/person/output_row.dart';

// E5.3 (Rui 25 Sep, Scientific Outputs A4·7, A4·8, B4·6).
Map<String, dynamic> author({
  String type = 'Artigos em revistas',
  String? subtype = 'Artigo',
  String source = 'manual',
  List<String> codes = const [],
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

  testWidgets('the first issue is written in full, with a count of the rest', (
    tester,
  ) async {
    await pumpRow(tester, author(codes: ['missing_doi', 'missing_year']));
    expect(find.text('Missing DOI +1'), findsOneWidget);
  });

  testWidgets('no issues says so', (tester) async {
    await pumpRow(tester, author());
    expect(find.text('No issues'), findsOneWidget);
  });

  testWidgets('ORCID state is text, not a tick', (tester) async {
    await pumpRow(tester, author());
    expect(find.text('Not on ORCID'), findsOneWidget);
    await pumpRow(tester, author(source: 'orcid'));
    expect(find.text('On ORCID'), findsOneWidget);
  });

  testWidgets('only featurable rows (publications) get a star', (tester) async {
    await pumpRow(tester, author(), featurable: false);
    expect(find.byIcon(Icons.star_border), findsNothing);
    await pumpRow(tester, author(), featurable: true);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });
}
