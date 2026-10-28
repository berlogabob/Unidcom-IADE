import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/panels.dart';
import 'package:unidcom_iade/widgets/sanity_sync_chip.dart';

void main() {
  for (final (date, error, label, tone) in [
    (null, null, 'Not on Sanity', PillTone.grey),
    ('2026-10-28T12:00:00Z', null, 'On Sanity · 28 Oct', PillTone.green),
    (
      '2026-10-28T12:00:00Z',
      'Sanity 400: rejected',
      'Sanity failed',
      PillTone.red,
    ),
  ]) {
    testWidgets(label, (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SanitySyncChip(syncedAt: date, error: error),
          ),
        ),
      );
      expect(find.text(label), findsOneWidget);
      expect(tester.widget<StatusPill>(find.byType(StatusPill)).tone, tone);
      expect(find.text('Retry'), findsNothing);
      if (error != null) expect(find.byTooltip(error), findsOneWidget);
    });
  }

  testWidgets('Retry calls the callback and disables until complete', (
    tester,
  ) async {
    var calls = 0;
    final complete = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SanitySyncChip(
            error: 'Failed',
            onRetry: () async {
              calls++;
              await complete.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Retrying…'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    complete.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Retry'), findsOneWidget);
  });
}
