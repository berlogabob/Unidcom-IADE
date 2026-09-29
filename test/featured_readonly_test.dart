import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unidcom_iade/widgets/featured_readonly.dart';

// E4.5 (Rui 25 Sep, My Profile B3·8): selected featured outputs, read only,
// max 5, with a link to Scientific Outputs. No checkboxes, no stars.
Future<void> pump(
  WidgetTester tester,
  List<Map<String, dynamic>> featured,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: FeaturedReadOnly(featured: featured)),
      ),
      GoRoute(
        path: '/app/outputs',
        builder: (_, state) => Text('outputs ${state.uri.query}'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  final two = [
    {
      'id': '1',
      'title': 'Design Systems',
      'type': 'Livros',
      'reporting_year': 2024,
    },
    {
      'id': '2',
      'title': 'Co-design Methods',
      'type': 'Artigos em revistas',
      'reporting_year': 2025,
    },
  ];

  testWidgets('header counts against 5, rows show title · type · year', (
    tester,
  ) async {
    await pump(tester, two);
    expect(find.text('Featured outputs (2/5)'), findsOneWidget);
    expect(find.text('Design Systems'), findsOneWidget);
    expect(find.text('Livros · 2024'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('Manage link opens Scientific Outputs on the featured view', (
    tester,
  ) async {
    await pump(tester, two);
    await tester.tap(find.text('Manage in Scientific Outputs →'));
    await tester.pumpAndSettle();
    expect(find.text('outputs view=featured'), findsOneWidget);
  });

  testWidgets('empty state explains where to choose', (tester) async {
    await pump(tester, const []);
    expect(find.text('Featured outputs (0/5)'), findsOneWidget);
    expect(
      find.text(
        'Choose up to 5 publications to feature in Scientific Outputs.',
      ),
      findsOneWidget,
    );
  });
}
