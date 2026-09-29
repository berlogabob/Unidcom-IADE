import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/detail_scaffold.dart';

void main() {
  Future<void> pump(WidgetTester tester, String text) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: editField(
          TextEditingController(text: text),
          'Bio',
          maxLines: 4,
          softMaxLength: 300,
        ),
      ),
    ),
  );

  testWidgets('bio counter counts against 300', (tester) async {
    await pump(tester, 'abc');
    expect(find.text('3 / 300'), findsOneWidget);
  });

  testWidgets('over 300 is counted, not cut', (tester) async {
    final long = 'x' * 450;
    await pump(tester, long);
    expect(
      find.text('450 / 300 · the website shows the first 300'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      long,
    );
  });
}
