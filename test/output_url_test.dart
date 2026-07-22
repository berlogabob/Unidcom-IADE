import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/output_row.dart';

void main() {
  test('prefers explicit url', () {
    expect(
      resolveOutputUrl('https://example.com/paper', '10.1/abc'),
      'https://example.com/paper',
    );
  });

  test('falls back to DOI resolver', () {
    expect(resolveOutputUrl(null, '10.1/abc'), 'https://doi.org/10.1/abc');
    expect(resolveOutputUrl('  ', '10.1/abc'), 'https://doi.org/10.1/abc');
  });

  test('null when nothing to open', () {
    expect(resolveOutputUrl(null, null), isNull);
    expect(resolveOutputUrl('', '  '), isNull);
  });
}
