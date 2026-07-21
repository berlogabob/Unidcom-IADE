import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/main.dart';

void main() {
  testWidgets('shows people screen', (tester) async {
    await tester.pumpWidget(const UnidcomApp());

    expect(find.text('People'), findsOneWidget);
  });
}
