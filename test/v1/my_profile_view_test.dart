import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/v1/my_profile_view.dart';

// Rui 25 Sep, My Profile TARGET LAYOUT (B3 + A3): title card · ORCID block ·
// [details | featured] · bio · [ORCID iD | Save draft + Submit]. One page, one
// design system (DsPage + Panel), inline editing — no dialog.
Map<String, dynamic> person({String bio = 'Old bio'}) => {
  'id': 'p1',
  'preferred_name': 'Ana Nolasco',
  'membership_type': 'integrated',
  'job_title': 'Researcher',
  'email': 'ana@iade.pt',
  'ciencia_id': 'C123-4567-A',
  'orcid': '0000-0002-1234-5678',
  'orcid_synced_at': '2026-09-21T10:00:00Z',
  'bio': bio,
  'profile_status': 'to_validate',
  'public_visibility': true,
};

Future<Map<String, List<Map<String, String>>>> pump(
  WidgetTester tester, {
  String? orcidBio,
}) async {
  tester.view.physicalSize = const Size(1400, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final calls = <String, List<Map<String, String>>>{'draft': [], 'submit': []};
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MyProfileView(
          person: person(),
          labs: const ['IXD/UX — Interaction & UX'],
          featured: const [
            {'id': 'o1', 'title': 'Design Systems', 'type': 'Livros', 'reporting_year': 2024},
          ],
          orcidBio: orcidBio,
          onSaveDraft: (proposed) async {
            calls['draft']!.add(proposed);
          },
          onSubmit: (proposed) async {
            calls['submit']!.add(proposed);
          },
          onImportOrcid: () {},
          onUploadPhoto: () {},
          onManageFeatured: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

double top(WidgetTester t, String text) => t.getTopLeft(find.text(text).first).dy;

void main() {
  testWidgets('blocks appear in the target order', (tester) async {
    await pump(tester);
    expect(find.text('My Profile'), findsOneWidget);
    expect(
      find.text('Your public researcher profile on the UNIDCOM website. UNIDCOM reviews before publishing.'),
      findsOneWidget,
    );
    final title = top(tester, 'My Profile');
    final orcid = top(tester, 'Import from ORCID');
    final details = top(tester, 'Your details');
    final featured = top(tester, 'Featured outputs (1/5)');
    final bio = top(tester, 'Biography');
    final orcidId = top(tester, 'ORCID iD');
    final save = top(tester, 'Save draft');
    expect(title < orcid && orcid < details, isTrue);
    expect((details - featured).abs() < 4, isTrue, reason: 'details and featured share a row');
    expect(details < bio && bio < orcidId, isTrue);
    expect((orcidId - save).abs() < 40, isTrue, reason: 'ORCID iD and actions share a row');
  });

  testWidgets('details show every field with an info icon', (tester) async {
    await pump(tester);
    for (final label in ['Name', 'Ciência ID', 'Lab / cluster', 'Email']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('IXD/UX — Interaction & UX'), findsOneWidget);
    expect(find.text('Upload photo'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsAtLeastNWidgets(6));
  });

  testWidgets('bio is edited in place with a counter against 300', (tester) async {
    await pump(tester);
    expect(find.text('7 / 300'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Old bio'), 'New bio text');
    await tester.pump();
    expect(find.text('12 / 300'), findsOneWidget);
  });

  testWidgets('Save draft and Submit send only what changed', (tester) async {
    final calls = await pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Old bio'), 'New bio text');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(calls['draft'], [
      {'bio': 'New bio text'},
    ]);
    await tester.tap(find.text('Submit for UNIDCOM review'));
    await tester.pumpAndSettle();
    expect(calls['submit']!.single['bio'], 'New bio text');
  });

  testWidgets('Import bio from ORCID shows only when ORCID differs, and fills the box', (tester) async {
    await pump(tester, orcidBio: 'Bio from ORCID');
    await tester.tap(find.text('Import bio from ORCID →'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Bio from ORCID'), findsOneWidget);
  });

  testWidgets('no Import bio link when ORCID has the same text', (tester) async {
    await pump(tester, orcidBio: 'Old bio');
    expect(find.text('Import bio from ORCID →'), findsNothing);
  });
}
