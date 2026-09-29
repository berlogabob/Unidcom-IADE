import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unidcom_iade/app/researcher_home.dart';

// E3.3 / E3.4 (Rui 25 Sep, Overview B2·5 and B2·6).
Future<void> pumpAt(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: SingleChildScrollView(child: home)),
      ),
      GoRoute(
        path: '/app/outputs',
        builder: (_, state) => Text('outputs ${state.uri.query}'),
      ),
      GoRoute(
        path: '/app/profile',
        builder: (_, _) => const Text('profile page'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bio shows its first lines and Edit bio opens My Profile', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const OverviewBio(bio: 'Researcher in design systems.'),
    );
    expect(find.text('Researcher in design systems.'), findsOneWidget);
    await tester.tap(find.text('Edit bio →'));
    await tester.pumpAndSettle();
    expect(find.text('profile page'), findsOneWidget);
  });

  testWidgets('empty bio offers to add one', (tester) async {
    await pumpAt(tester, const OverviewBio(bio: null));
    expect(find.text('No biography yet'), findsOneWidget);
    expect(find.text('Add bio →'), findsOneWidget);
  });

  testWidgets('a type tile opens Scientific Outputs filtered by that type', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const OutputSummary(
        outputs: [
          {'id': '1', 'category_path': 'Livros › Autor'},
          {'id': '2', 'category_path': 'Livros'},
        ],
        featured: 1,
      ),
    );
    await tester.tap(find.text('LIVROS'));
    await tester.pumpAndSettle();
    expect(find.text('outputs type=Livros'), findsOneWidget);
  });

  testWidgets('Featured opens Scientific Outputs on the featured view', (
    tester,
  ) async {
    await pumpAt(
      tester,
      const OutputSummary(
        outputs: [
          {'id': '1', 'category_path': 'Livros'},
        ],
        featured: 1,
      ),
    );
    await tester.tap(find.text('FEATURED OUTPUTS'));
    await tester.pumpAndSettle();
    expect(find.text('outputs view=featured'), findsOneWidget);
  });
}
