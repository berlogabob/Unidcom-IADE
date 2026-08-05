import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/panels.dart';

void main() {
  testWidgets('renders shared panel widgets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const Panel(
                  title: 'Panel title',
                  trailing: Text('Panel action'),
                  child: Text('Panel body'),
                ),
                const AccentStatCard(
                  label: 'Members',
                  value: '42',
                  sub: 'Active this month',
                  tone: AccentTone.good,
                ),
                const StatusPill('Approved', tone: PillTone.green),
                const TypeBadge('Report', tone: PillTone.blue),
                FilterPill('All outputs', selected: true, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );

    for (final text in [
      'Panel title',
      'Panel action',
      'Panel body',
      'MEMBERS',
      '42',
      'Active this month',
      'Approved',
      'REPORT',
      'All outputs',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
  });
}
