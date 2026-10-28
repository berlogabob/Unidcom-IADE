import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/website_sync.dart';
import 'package:unidcom_iade/widgets/suggestion_tile.dart';

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

  const last = {
    'status': 'completed',
    'conclusion': 'success',
    'started_at': '2026-10-08T09:00:00Z',
    'updated_at': '2026-10-08T09:02:00Z',
  };

  testWidgets('lists only people published after the known sync time', (
    tester,
  ) async {
    await pump(
      tester,
      last: last,
      waiting: [
        {'preferred_name': 'Ana Silva', 'published_at': '2026-10-08T10:00:00Z'},
        {
          'preferred_name': 'Before sync',
          'published_at': '2026-10-08T08:00:00Z',
        },
        {'preferred_name': 'At sync', 'published_at': '2026-10-08T09:00:00Z'},
      ],
    );
    expect(find.text('Ana Silva'), findsOneWidget);
    expect(find.text('Before sync'), findsNothing);
    expect(find.text('At sync'), findsNothing);
    expect(find.text('Waiting for the next sync'), findsOneWidget);
  });

  testWidgets('says so when nothing is waiting', (tester) async {
    await pump(tester, last: last);
    expect(find.text('Nothing is waiting for the sync.'), findsOneWidget);
  });

  testWidgets('shows the last run and the ready-to-publish count', (
    tester,
  ) async {
    final calls = await pump(tester, last: last);
    expect(
      find.text(
        'Last sync: ${dayLabel(DateTime.parse(last['updated_at']!).toLocal())}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('2 researchers are accepted but not published'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open Ready to publish'));
    expect(calls, ['ready']);
  });

  testWidgets(
    'unknown sync time shows automatic sync guidance and no waiting section',
    (tester) async {
      for (final record in [
        null,
        <String, dynamic>{'status': 'completed'},
      ]) {
        await pump(
          tester,
          last: record,
          waiting: [
            {
              'preferred_name': 'Already published',
              'published_at': '2026-10-08T10:00:00Z',
            },
          ],
        );
        if (record == null) {
          expect(
            find.text(
              'The website syncs by itself every 10 minutes; use Retry only if a change does not appear.',
            ),
            findsOneWidget,
          );
        }
        expect(find.text('Last sync: never run'), findsNothing);
        expect(find.text('Waiting for the next sync'), findsNothing);
        expect(find.text('Nothing is waiting for the sync.'), findsNothing);
        expect(find.text('Already published'), findsNothing);
        expect(
          find.text('2 researchers are accepted but not published'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('sync asks first, and cancel does nothing', (tester) async {
    final calls = await pump(tester);
    await tester.tap(find.text('Retry website sync'));
    await tester.pumpAndSettle();
    expect(find.text('Update the UNIDCOM website now?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.text('Retry website sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync'));
    await tester.pumpAndSettle();
    expect(calls, ['sync']);
  });
}
