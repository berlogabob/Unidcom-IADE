import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/website_sync.dart';

// Spec for the admin "Website" page: what the next sync will publish, the last
// run, and a Sync button that asks for confirmation.
void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    Map<String, dynamic>? last,
    int ready = 2,
    List<Map<String, dynamic>> waiting = const [],
  }) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebsiteSyncView(
            last: last,
            readyCount: ready,
            waiting: waiting,
            onSync: () async => calls.add('sync'),
            onOpenReady: () => calls.add('ready'),
          ),
        ),
      ),
    );
    return calls;
  }

  testWidgets('lists who the next sync will put on the site', (tester) async {
    await pump(
      tester,
      waiting: [
        {'preferred_name': 'Ana Silva', 'published_at': '2026-10-08T10:00:00Z'},
      ],
    );
    expect(find.text('Ana Silva'), findsOneWidget);
    expect(find.text('Waiting for the next sync'), findsOneWidget);
  });

  testWidgets('says so when nothing is waiting', (tester) async {
    await pump(tester);
    expect(find.text('Nothing is waiting for the sync.'), findsOneWidget);
  });

  testWidgets('shows the last run and the ready-to-publish count', (tester) async {
    final calls = await pump(
      tester,
      last: {
        'status': 'completed',
        'conclusion': 'success',
        'updated_at': '2026-10-09T04:02:00Z',
      },
    );
    expect(find.textContaining('Last sync: succeeded'), findsOneWidget);
    expect(find.textContaining('2 researchers are accepted but not published'), findsOneWidget);
    await tester.tap(find.text('Open Ready to publish'));
    expect(calls, ['ready']);
  });

  testWidgets('sync asks first, and cancel does nothing', (tester) async {
    final calls = await pump(tester);
    await tester.tap(find.text('Sync to website'));
    await tester.pumpAndSettle();
    expect(find.text('Update the UNIDCOM website now?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.text('Sync to website'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync'));
    await tester.pumpAndSettle();
    expect(calls, ['sync']);
  });
}
