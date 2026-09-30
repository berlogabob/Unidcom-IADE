import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/v1/my_profile_view.dart';

// Rui's v1.0 brief (PR-1..PR-6, G-5) and RIMSv1/My Profile.png: title card with
// Save draft + Submit top right · ORCID box · [Identity & bio | Featured].
// ORCID is import-only: "Import from ORCID" fills the form; nothing is sent
// until Submit for UNIDCOM review.
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
  Map<String, String>? orcid,
  List<String>? connects,
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
          orcid: orcid,
          onSaveDraft: (proposed) async {
            calls['draft']!.add(proposed);
          },
          onSubmit: (proposed) async {
            calls['submit']!.add(proposed);
          },
          onConnectOrcid: () => connects?.add('connect'),
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
    final save = top(tester, 'Save draft');
    final submit = top(tester, 'Submit for UNIDCOM review');
    final orcid = top(tester, 'Import from ORCID');
    final identity = top(tester, 'Identity & bio');
    final featured = top(tester, 'Featured outputs (1/5)');
    expect((save - title).abs() < 40 && (submit - title).abs() < 40, isTrue,
        reason: 'Save draft and Submit sit in the title card, top right');
    expect(tester.getTopLeft(find.text('Submit for UNIDCOM review')).dx > 700, isTrue);
    expect(title < orcid && orcid < identity, isTrue);
    expect((identity - featured).abs() < 4, isTrue, reason: 'identity and featured share a row');
    expect(find.text('Your details'), findsNothing);
    expect(find.text('Biography'), findsNothing);
  });

  testWidgets('ORCID box is light teal', (tester) async {
    await pump(tester);
    final box = tester.widget<Container>(find.ancestor(
      of: find.text('Import from ORCID'),
      matching: find.byType(Container),
    ).last);
    expect((box.decoration as BoxDecoration).color, const Color(0xFFE6F6F2));
    expect(find.text('Editing here does not change your ORCID record.'), findsOneWidget);
  });

  testWidgets('details show every field with an info icon', (tester) async {
    await pump(tester);
    for (final label in ['Name', 'Ciência ID', 'Lab / cluster', 'Email', 'ORCID iD', 'Bio']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('IXD/UX — Interaction & UX'), findsOneWidget);
    expect(find.text('Upload photo'), findsOneWidget);
    expect(find.text('0000-0002-1234-5678'), findsOneWidget);
    // photo, name·role, 6 fields, Import from ORCID, Save draft, Submit.
    expect(find.byIcon(Icons.info_outline), findsAtLeastNWidgets(11));
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
    await pump(tester, orcid: {'bio': 'Bio from ORCID'});
    await tester.tap(find.text('Import bio from ORCID →'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Bio from ORCID'), findsOneWidget);
  });

  testWidgets('no Import bio link when ORCID has the same text', (tester) async {
    await pump(tester, orcid: {'bio': 'Old bio'});
    expect(find.text('Import bio from ORCID →'), findsNothing);
  });

  testWidgets('Import from ORCID fills every differing field; Submit sends them', (tester) async {
    final calls = await pump(tester, orcid: {
      'bio': 'Bio from ORCID',
      'ciencia_id': 'C999-0000-B',
      'email': 'ana@iade.pt',
      'orcid': '0000-0002-1234-5678',
    });
    await tester.tap(find.text('Import from ORCID'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Bio from ORCID'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'C999-0000-B'), findsOneWidget);
    expect(find.textContaining('2 fields filled in from ORCID'), findsOneWidget);
    expect(calls['submit'], isEmpty, reason: 'import never sends by itself');
    await tester.tap(find.text('Submit for UNIDCOM review'));
    await tester.pumpAndSettle();
    expect(calls['submit']!.single, {'bio': 'Bio from ORCID', 'ciencia_id': 'C999-0000-B'});
  });

  testWidgets('Import from ORCID says so when nothing differs', (tester) async {
    await pump(tester, orcid: {'bio': 'Old bio', 'email': 'ana@iade.pt'});
    await tester.tap(find.text('Import from ORCID'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already matches ORCID'), findsOneWidget);
  });

  testWidgets('not connected: Connect ORCID starts linking, not an import', (tester) async {
    final connects = <String>[];
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MyProfileView(
          person: {...person(), 'orcid': null},
          labs: const [],
          featured: const [],
          onSaveDraft: (_) async {},
          onSubmit: (_) async {},
          onConnectOrcid: () => connects.add('connect'),
          onUploadPhoto: () {},
          onManageFeatured: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Connect ORCID'), findsOneWidget);
    expect(find.text('Import from ORCID'), findsNothing);
    await tester.tap(find.text('Connect ORCID'));
    expect(connects, ['connect']);
  });
}