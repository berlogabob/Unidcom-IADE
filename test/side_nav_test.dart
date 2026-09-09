import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/nav_model.dart';
import 'package:unidcom_iade/widgets/side_nav.dart';
import 'package:unidcom_iade/theme/tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 240, child: child)),
  );

  tearDown(() {
    expandedGroup.value = null;
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

  testWidgets('only one section is open: opening My Profile closes Overview', (
    tester,
  ) async {
    final groups = researcherNav(signedIn: true);
    await tester.pumpWidget(
      host(
        SideNav(
          groups: groups,
          path: '/app/home',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );
    // /app/home belongs to Overview, so that is the one open section.
    expect(find.text('Research Activity Summary'), findsOneWidget);
    expect(find.text('Biography'), findsNothing);

    await tester.tap(find.byKey(const Key('nav-toggle-My Profile')));
    await tester.pump();

    expect(find.text('Biography'), findsOneWidget);
    expect(find.text('Research Activity Summary'), findsNothing);
    expect(openGroup(groups, '/app/home'), 'My Profile');
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

  testWidgets('a closed section shows the closed chevron and tooltip', (
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

    // Accordion: on /app/home only Overview is open; My Profile is closed.
    expect(
      find.descendant(
        of: find.byKey(const Key('nav-toggle-My Profile')),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Show section'), findsWidgets);
    expect(find.byTooltip('Hide section'), findsOneWidget);
  });

  testWidgets('toggling the open section closes it; a new path reopens by route', (
    tester,
  ) async {
    final groups = researcherNav(signedIn: true);
    await tester.pumpWidget(
      host(
        SideNav(
          groups: groups,
          path: '/app/home',
          header: const SizedBox(),
          footer: const SizedBox(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('nav-toggle-Overview')));
    await tester.pump();
    expect(find.text('Research Activity Summary'), findsNothing);
    expect(openGroup(groups, '/app/home'), isNull);

    // The stored choice is bound to /app/home; another path follows its owner.
    expect(openGroup(groups, '/app/profile/bio'), 'My Profile');
  });

  testWidgets('footer separates from and does not cover the last nav row', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        host(
          SideNav(
            groups: researcherNav(signedIn: true),
            path: '/app/help/faq', // accordion: FAQs is only rendered while its section is open
            header: const SizedBox(),
            footer: const SizedBox(height: 160),
          ),
        ),
      );

      await tester.scrollUntilVisible(find.text('FAQs'), 100);
      final footer = tester.widget<Container>(
        find.byKey(const Key('nav-footer')),
      );
      final decoration = footer.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.sidebar);
      expect(
        decoration.border!.top.color,
        AppColors.textOnDarkMuted.withValues(alpha: 0.25),
      );
      expect(
        tester.getRect(find.text('FAQs')).overlaps(
          tester.getRect(find.byKey(const Key('nav-footer'))),
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
