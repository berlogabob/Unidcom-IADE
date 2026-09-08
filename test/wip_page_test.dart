import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/portal_pages.dart';

void main() {
  testWidgets('shows the title, the WIP notice, and the note', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WipPage(title: 'FAQs', note: 'x'),
      ),
    );
    expect(find.text('FAQs'), findsOneWidget);
    expect(find.text('Work in progress'), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
  });
}
