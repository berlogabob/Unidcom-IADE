import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/welcome_pack.dart';

void main() {
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
  testWidgets('social media cards are links to the real pages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WelcomePackPage(section: 'social')),
      ),
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^https://www\.(instagram|facebook|linkedin)\.com/'),
      ),
      findsNWidgets(3),
    );
  });
  testWidgets('FCT Information section shows correct content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WelcomePackPage(section: 'fct')),
      ),
    );
    expect(find.textContaining('FCT Information'), findsWidgets);
    expect(find.textContaining('Mandatory affiliation'), findsNothing);
  });
  testWidgets('resources section links to its five guidance pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WelcomePackPage(section: 'resources')),
      ),
    );
    for (final label in [
      'Affiliation Guidelines',
      'FCT Information',
      'Email Signature',
      'Social Media',
      'Logos & Brand',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Research Activity Reporting'), findsNothing);
  });
}
