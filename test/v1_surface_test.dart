import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/welcome_pack.dart';

void main() {
  test('v1 welcome pack offers exactly the seven sections Rui kept', () {
    final slugs = [
      for (final g in sectionGroups)
        for (final i in g.$2) i.$1,
    ];
    expect(slugs, [
      'start',
      'signature',
      'social',
      'affiliation',
      'report',
      'logos',
      'contacts',
    ]);
  });
  testWidgets('Getting started shows no advice callouts and no M2 references', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WelcomePackPage(section: 'start')),
      ),
    );
    expect(find.textContaining('Documents & forms'), findsNothing);
    expect(
      find.textContaining('All support requests require approval'),
      findsNothing,
    );
  });
  test('nav shows three group headers and none over Getting started', () {
    final titles = [for (final g in sectionGroups) g.$1];
    expect(titles.where((t) => t.isNotEmpty).length, 3);
    expect(sectionGroups.first.$1, isEmpty);
    expect(sectionGroups.first.$2.single.$1, 'start');
  });
}
