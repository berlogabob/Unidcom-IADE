import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/source_chip.dart';

void main() {
  testWidgets('manual and null sources render nothing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(children: [SourceChip(null), SourceChip('manual')]),
      ),
    );
    expect(find.text('from manual'), findsNothing);
    expect(find.byType(SourceChip), findsNWidgets(2));
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('renders a non-manual source', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SourceChip('sanity')));
    expect(find.text('from sanity'), findsOneWidget);
  });
}
