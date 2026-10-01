import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/ds_page.dart';

// User, 1 Oct: cards align in height and width; one row as wide as the header
// where they fit.
Future<void> pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: DsCardGrid(children: [
        for (var i = 0; i < 5; i++)
          Container(
            key: ValueKey('c$i'),
            color: Colors.white,
            child: Text(i == 2 ? 'long\ncard\ntext' : 'card $i'),
          ),
      ]),
    ),
  ));
}

Rect box(WidgetTester t, int i) => t.getRect(find.byKey(ValueKey('c$i')));

void main() {
  testWidgets('five cards fit one full-width row, equal widths and heights', (tester) async {
    await pump(tester, 1100);
    final first = box(tester, 0), last = box(tester, 4);
    expect(first.top, last.top);
    expect(first.left, 0);
    expect(last.right, 1100);
    for (var i = 1; i < 5; i++) {
      expect(box(tester, i).width, closeTo(first.width, 0.5));
      expect(box(tester, i).height, box(tester, 2).height);
    }
  });

  testWidgets('narrow: later rows keep the same columns', (tester) async {
    await pump(tester, 400);
    expect(box(tester, 2).left, box(tester, 0).left);
    expect(box(tester, 2).width, closeTo(box(tester, 0).width, 0.5));
    expect(tester.takeException(), isNull);
  });
}
