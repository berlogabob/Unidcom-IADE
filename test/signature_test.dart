import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/signature_form.dart';

void main() {
  testWidgets('fields prefill from the person and the preview follows edits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SignatureForm(
              person: {
                'id': 'p1',
                'preferred_name': 'Ana Nolasco',
                'email': 'ana@universidadeeuropeia.pt',
                'job_title': null,
                'phone': null,
              },
            ),
          ),
        ),
      ),
    );
    expect(find.widgetWithText(TextField, 'Ana Nolasco'), findsOneWidget);
    expect(find.text('Ana Nolasco'), findsNWidgets(2)); // field + preview
    await tester.enterText(
      find.byKey(const Key('sig-role')),
      'Associate Professor',
    );
    await tester.pump();
    expect(find.text('Associate Professor'), findsNWidgets(2));
  });

  testWidgets('anonymous visitor gets an empty form with placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SignatureForm(person: null)),
        ),
      ),
    );
    expect(find.text('Name Surname'), findsWidgets);
  });

  test('signatureText uses placeholders for empty fields', () {
    expect(
      signatureText(name: '', role: '', email: '', phone: ''),
      contains('Name Surname'),
    );
    expect(
      signatureText(name: 'A', role: 'B', email: 'c@d', phone: '+351 1'),
      contains('E c@d · M +351 1'),
    );
  });
}
