import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/queue_list.dart';

void main() {
  test('humanises known status labels and falls back for unknown values', () {
    expect(queueStatusLabel('a_confirmar'), 'To confirm');
    expect(queueStatusLabel('some_other'), 'some other');
  });
}
