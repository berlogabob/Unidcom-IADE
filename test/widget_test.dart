import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('shows login screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('failed password sign-in shows a SnackBar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          signIn: ({required email, required password}) async {
            throw const AuthException('Invalid login credentials');
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'person@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.text('Invalid login credentials'),
      ),
      findsNothing,
    );
  });

  testWidgets('empty password stays inline validation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.enterText(find.byType(TextField).at(0), 'person@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Password is required'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
