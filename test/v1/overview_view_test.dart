import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/v1/overview_view.dart';
import 'package:unidcom_iade/data/attention.dart';
import 'package:unidcom_iade/data/timeline.dart';

// Rui 25 Sep, Overview TARGET LAYOUT (B2 + A2·6, A2·9, A3·8): title card
// (name · researcher type) · yellow "Needs your attention" · dated timeline ·
// [Bio | Summary] · three recent-output cards naming the issue.
Map<String, dynamic> out(String id, String title, String path, int year, {List<String> codes = const []}) => {
  'id': id,
  'title': title,
  'category_path': path,
  'type': path.split(' › ').first,
  'reporting_year': year,
  'issue_codes': codes,
  'warning_count': codes.length,
  'error_count': 0,
  'approval_status': 'to_validate',
};

Future<List<String>> pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final routes = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OverviewView(
          person: const {
            'preferred_name': 'Ana Nolasco',
            'membership_type': 'integrated',
            'bio': 'Researcher in interaction design and HCI.',
          },
          alerts: const [AttentionItem('3 outputs have issues → Review', '/app/outputs')],
          timeline: [
            TimelineStep('Draft', StepState.done, DateTime.utc(2026, 8, 4)),
            const TimelineStep('Submitted', StepState.current),
            const TimelineStep('Under review', StepState.todo),
            const TimelineStep('Published', StepState.todo),
          ],
          outputs: [
            out('1', 'Accessibility in Co-Design', 'Artigos em revistas', 2025, codes: ['missing_doi']),
            out('2', 'Participatory Design', 'Livros › Autor', 2024),
            out('3', 'Service Design', 'Livros › Autor', 2023),
            out('4', 'Older Work', 'Livros', 2020),
          ],
          featuredCount: 2,
          onNavigate: routes.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return routes;
}

double top(WidgetTester t, Finder f) => t.getTopLeft(f.first).dy;

void main() {
  testWidgets('blocks appear in the target order', (tester) async {
    await pump(tester);
    expect(find.text('Ana Nolasco'), findsOneWidget);
    expect(find.text('Integrated researcher'), findsOneWidget);
    final title = top(tester, find.text('Ana Nolasco'));
    final banner = top(tester, find.text('3 outputs have issues → Review'));
    final timeline = top(tester, find.text('Under review'));
    final bio = top(tester, find.text('Bio'));
    final summary = top(tester, find.text('Summary'));
    final recent = top(tester, find.text('Recent outputs'));
    expect(title < banner && banner < timeline && timeline < bio, isTrue);
    expect((bio - summary).abs() < 4, isTrue, reason: 'Bio and Summary share a row');
    expect(bio < recent, isTrue);
  });

  testWidgets('summary counts per type, issues and featured; numbers open outputs filtered', (tester) async {
    final routes = await pump(tester);
    expect(find.text('4 outputs'), findsOneWidget);
    expect(find.text('3 Livros'), findsOneWidget);
    expect(find.text('1 with issues'), findsOneWidget);
    expect(find.text('Featured 2/5'), findsOneWidget);
    await tester.tap(find.text('3 Livros'));
    await tester.tap(find.text('1 with issues'));
    await tester.tap(find.text('Featured 2/5'));
    expect(routes, [
      '/app/outputs?type=Livros',
      '/app/outputs?issues=1',
      '/app/outputs?view=featured',
    ]);
  });

  testWidgets('three recent outputs, issue named in full', (tester) async {
    await pump(tester);
    expect(find.text('Accessibility in Co-Design'), findsOneWidget);
    expect(find.text('Service Design'), findsOneWidget);
    expect(find.text('Older Work'), findsNothing);
    expect(find.text('Missing DOI'), findsOneWidget);
    expect(find.text('No issues'), findsNWidgets(2));
  });

  testWidgets('bio shows first lines and Edit bio opens My Profile', (tester) async {
    final routes = await pump(tester);
    expect(find.text('Researcher in interaction design and HCI.'), findsOneWidget);
    await tester.tap(find.text('Edit bio →'));
    expect(routes, ['/app/profile']);
  });
}
