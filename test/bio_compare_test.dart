import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/public/person/profile_sections.dart';

void main() {
  final person = <String, dynamic>{'bio': 'UNIDCOM bio'};

  Widget host(
    Map<String, dynamic> value, {
    String? orcidBio,
    VoidCallback? onImport,
  }) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: personBioSection(
            context,
            value,
            orcidBio: orcidBio,
            onImportOrcid: onImport,
          ),
        ),
      ),
    ),
  );

  testWidgets('different bios can be proposed for import', (tester) async {
    var imports = 0;
    await tester.pumpWidget(
      host(person, orcidBio: 'ORCID bio', onImport: () => imports++),
    );

    expect(find.text('UNIDCOM biography'), findsOneWidget);
    expect(find.text('ORCID biography'), findsOneWidget);
    await tester.tap(find.text('Import ORCID version'));
    expect(imports, 1);
  });

  testWidgets('equal bios show a match', (tester) async {
    await tester.pumpWidget(host(person, orcidBio: '  UNIDCOM bio  '));

    expect(find.text('Matches ORCID'), findsOneWidget);
    expect(find.text('Import ORCID version'), findsNothing);
  });

  testWidgets('missing ORCID bio keeps the current rendering', (tester) async {
    await tester.pumpWidget(host(person));

    expect(find.text('About'), findsOneWidget);
    expect(find.text('UNIDCOM biography'), findsNothing);
    expect(find.text('ORCID biography'), findsNothing);
  });

  testWidgets('ORCID sync date is formatted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: personIdentifiersSections(
                context,
                {
                  'orcid': '0000-0001-2345-6789',
                  'orcid_synced_at': '2026-09-10T14:17:41Z',
                },
                onOpen: (_) {},
                onConnectOrcid: () {},
                showConnect: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Last synchronised'), findsOneWidget);
    expect(find.text('10 Sep 2026'), findsOneWidget);
  });
}
