import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/info_tip.dart';

void main() {
  testWidgets('InfoTip renders an Icons.info_outline icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InfoTip(text: 'Test text')),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
    expect(icon, isNotNull);
  });

  testWidgets('InfoTip Tooltip message equals the given text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InfoTip(text: 'Test message')),
      ),
    );

    final tooltip = find.byTooltip('Test message');
    expect(tooltip, isNotNull);
  });

  testWidgets('WithInfo finds text and info_outline icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WithInfo(info: 'x', child: const Text('Email')),
        ),
      ),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
