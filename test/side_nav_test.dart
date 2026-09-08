import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/nav_model.dart';
import 'package:unidcom_iade/widgets/side_nav.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 240, child: child)),
  );

  tearDown(() {
    collapsedGroups.value = {};
  });

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

  testWidgets(
    'anonymous researcher nav has no My Profile / My Outputs, has Getting Started',
    (tester) async {
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
      expect(find.text('MY PROFILE'), findsNothing);
      expect(find.text('My Outputs'), findsNothing);
      expect(find.text('Getting Started'), findsOneWidget);
    },
  );

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

  testWidgets('a section header can be collapsed and expanded', (tester) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: researcherNav(signedIn: true),
          path: '/app/home',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );
    expect(find.text('Biography'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-toggle-My Profile')));
    await tester.pump();

    expect(find.text('Biography'), findsNothing);
    expect(collapsedGroups.value, contains('My Profile'));
  });

  testWidgets('tapping a group header label navigates to its landing route', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: researcherNav(signedIn: true),
          path: '/app/home',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );
    expect(find.byKey(const Key('nav-group-My Profile')), findsOneWidget);
  });

  testWidgets('a collapsed section shows the closed chevron and tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: researcherNav(signedIn: true),
          path: '/app/home',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('nav-toggle-My Profile')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('nav-toggle-My Profile')),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Show section'), findsOneWidget);
  });

  testWidgets('toggling a section twice restores its items', (tester) async {
    await tester.pumpWidget(
      host(
        SideNav(
          groups: researcherNav(signedIn: true),
          path: '/app/home',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('nav-toggle-My Profile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('nav-toggle-My Profile')));
    await tester.pump();

    expect(find.text('Biography'), findsOneWidget);
    expect(collapsedGroups.value, isEmpty);
  });
}
