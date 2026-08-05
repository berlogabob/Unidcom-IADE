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

  testWidgets('FilterPill fires onTap', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilterPill(
            'All',
            selected: false,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(tapped, false);
    await tester.tap(find.text('All'));
    expect(tapped, true);
  });

  testWidgets('StatusPill renders every tone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (final tone in PillTone.values)
                StatusPill(tone.name, tone: tone),
            ],
          ),
        ),
      ),
    );

    for (final tone in PillTone.values) {
      expect(find.text(tone.name), findsOneWidget);
    }
  });

  testWidgets('AccentStatCard shows label value sub', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccentStatCard(
            label: 'OUTPUTS',
            value: '12',
            sub: '+2 this year',
            tone: AccentTone.good,
          ),
        ),
      ),
    );

    expect(find.text('OUTPUTS'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('+2 this year'), findsOneWidget);
  });
}
