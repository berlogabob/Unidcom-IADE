import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/review_queue.dart';

void main() {
  testWidgets('reject dialog passes a reason and cancel makes no data call', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRejectOutputDialog(
              context,
              title: 'Rejected output',
              onReject: (reason) async => calls++,
            ),
            child: const Text('Reject'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(find.text('Reject “Rejected output”?'), findsOneWidget);
    expect(find.text('Reason (shown to the researcher)'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Please add the missing DOI.',
    );
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
