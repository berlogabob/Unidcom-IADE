import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/supabase.dart';

void main() {
  test('suggestionRows stages changed output fields', () {
    final rows = suggestionRows(
      'output',
      'out-1',
      {'title': 'Old title', 'doi': '10.1/old'},
      {'title': ' New title ', 'doi': '10.1/old'},
    );

    expect(rows, [
      {
        'subject_type': 'output',
        'subject_id': 'out-1',
        'field': 'title',
        'current_value': 'Old title',
        'suggested_value': 'New title',
        'source': 'researcher',
        'confidence': 1,
      },
    ]);
  });

  test('signatureSuggestions keeps person subject type', () {
    final rows = signatureSuggestions(
      'person-1',
      {'email': 'old@example.com'},
      {'email': 'new@example.com'},
    );

    expect(rows.single['subject_type'], 'person');
  });
}
