import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/nav_model.dart';
import 'package:unidcom_iade/widgets/side_nav.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 240, child: child)),
  );

  testWidgets('active row carries the key and its label appears once', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: adminNav(),
          path: '/labs/x',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );
    expect(find.text('Structure'), findsOneWidget);
    expect(find.byKey(const Key('nav-active')), findsOneWidget);
  });

  testWidgets('anonymous researcher nav has no Overview', (tester) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: researcherNav(signedIn: false),
          path: '/app/welcome/start',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );
    expect(find.text('Overview'), findsNothing);
  });

  testWidgets('group labels render uppercase, only when non-empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: adminNav(),
          path: '/app/dashboard',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );
    expect(find.text('RESEARCH'), findsOneWidget);
  });

  testWidgets('children render whether or not their parent is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: adminNav(),
          path: '/app/dashboard', // Dashboard active, not People
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );
    expect(find.text('Merge duplicates'), findsOneWidget);
  });

  testWidgets('a positive badge count shows the amber pill', (tester) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: adminNav(),
          path: '/app/dashboard',
          header: const SizedBox(),
          footer: const SizedBox(),
          badges: {'/people': Future.value(3)},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a zero badge count shows nothing', (tester) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: adminNav(),
          path: '/app/dashboard',
          header: const SizedBox(),
          footer: const SizedBox(),
          badges: {'/people': Future.value(0)},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing);
  });
}
