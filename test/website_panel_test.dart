import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unidcom_iade/widgets/website_panel.dart';

Widget panel(
  Map<String, dynamic> output,
  Future<void> Function(String, String) onChange,
) => MaterialApp(
  home: Scaffold(
    body: WebsitePanel(output: output, onChange: onChange),
  ),
);

void main() {
  testWidgets('publishes and updates optimistically', (tester) async {
    final changes = <(String, String)>[];
    await tester.pumpWidget(
      panel({
        'id': 'id1',
        'approval_status': 'approved',
        'website_status': 'not_published',
      }, (id, status) async => changes.add((id, status))),
    );
    expect(find.text('Website · Not published'), findsOneWidget);
    await tester.tap(find.text('Publish to website'));
    await tester.pumpAndSettle();
    expect(changes, [('id1', 'published')]);
    expect(find.text('Website · Published'), findsOneWidget);
    expect(find.text('Unpublish'), findsOneWidget);
  });

  testWidgets('hides actions before approval', (tester) async {
    await tester.pumpWidget(
      panel({
        'id': 'id1',
        'approval_status': 'pending',
        'website_status': 'not_published',
      }, (_, _) async {}),
    );
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(
      find.text(
        'Approve the output first; publication is a separate decision.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows publication errors', (tester) async {
    await tester.pumpWidget(
      panel({
        'id': 'id1',
        'approval_status': 'approved',
        'website_status': 'error',
      }, (_, _) async {}),
    );
    expect(find.text('Website · Publication error'), findsOneWidget);
  });
}
