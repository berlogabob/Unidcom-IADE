import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/change_compare.dart';

// Spec for the review card body (brief RV-3): Now / Proposed, long text cut to
// 3 lines with "Show full text" that expands both; photos shown side by side.
void main() {
  Future<void> pump(WidgetTester tester, String field, String? now, String proposed) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: ChangeCompare(field: field, now: now, proposed: proposed),
            ),
          ),
        ),
      );

  final long = List.filled(40, 'participatory design').join(' ');

  testWidgets('short text shows Now and Proposed with no toggle', (tester) async {
    await pump(tester, 'bio', 'Old bio', 'New bio');
    expect(find.text('Now: Old bio'), findsOneWidget);
    expect(find.text('Proposed: New bio'), findsOneWidget);
    expect(find.text('Show full text'), findsNothing);
  });

  testWidgets('empty current value reads "empty"', (tester) async {
    await pump(tester, 'ciencia_id', null, '6414-x');
    expect(find.text('Now: empty'), findsOneWidget);
  });

  testWidgets('long text is cut to 3 lines and expands both sides', (tester) async {
    await pump(tester, 'bio', long, '$long more');
    Text proposed() =>
        tester.widget<Text>(find.textContaining('Proposed:'));
    expect(proposed().maxLines, 3);
    await tester.tap(find.text('Show full text'));
    await tester.pump();
    expect(proposed().maxLines, isNull);
    expect(tester.widget<Text>(find.textContaining('Now:')).maxLines, isNull);
    expect(find.text('Hide full text'), findsOneWidget);
  });

  testWidgets('a photo change shows two small images side by side', (tester) async {
    await pump(tester, 'photo_url', 'https://x.test/a.jpg', 'https://x.test/b.jpg');
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Proposed'), findsOneWidget);
  });
}
