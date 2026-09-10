import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/attention.dart';

void main() {
  test('attention rules preserve order, wording, and routes', () {
    final items = attentionItems(
      person: {'profile_status': 'draft'},
      outputs: [
        {'approval_status': 'rejected', 'error_count': 0},
        {'approval_status': 'approved', 'error_count': 2},
        {'approval_status': 'approved', 'error_count': 1},
      ],
      candidates: [
        {'status': 'pending', 'matched_output_id': null},
        {'status': 'pending', 'matched_output_id': 'output-1'},
        {'status': 'pending', 'matched_output_id': 'output-2'},
      ],
      suggestions: [
        {'status': 'rejected', 'source': 'researcher'},
        {'status': 'rejected', 'source': 'researcher'},
      ],
    );

    expect(items.map((item) => (item.text, item.route)), [
      ('Your profile is not confirmed yet → Confirm it', '/app/profile'),
      ('1 ORCID publication needs your review', '/app/outputs/import'),
      ('2 possible duplicates detected', '/app/outputs/import'),
      ('1 output needs changes (UNIDCOM feedback)', '/app/outputs'),
      ('2 outputs are missing required information', '/app/outputs'),
      ('2 of your proposed changes were declined', '/app/profile'),
    ]);
  });

  test('singular wording and pending review are handled', () {
    final items = attentionItems(
      person: {'profile_status': 'pending_review'},
      outputs: const [],
      candidates: const [
        {'status': 'pending', 'matched_output_id': 'output-1'},
      ],
      suggestions: const [
        {'status': 'rejected', 'source': 'researcher'},
      ],
    );

    expect(items.map((item) => item.text), [
      '1 possible duplicate detected',
      '1 of your proposed change was declined',
    ]);
  });

  test('remaining singular and plural wording is grammatical', () {
    final items = attentionItems(
      person: const {},
      outputs: const [
        {'approval_status': 'rejected', 'error_count': 1},
        {'approval_status': 'rejected', 'error_count': 0},
      ],
      candidates: const [
        {'status': 'pending', 'matched_output_id': null},
        {'status': 'pending', 'matched_output_id': null},
      ],
      suggestions: const [],
    );

    expect(items.map((item) => item.text), [
      '2 ORCID publications need your review',
      '2 outputs need changes (UNIDCOM feedback)',
      '1 output is missing required information',
    ]);
    expect(items.map((item) => item.route), [
      '/app/outputs/import',
      '/app/outputs',
      '/app/outputs',
    ]);
  });

  test('pending review alone is not actionable', () {
    expect(
      attentionItems(
        person: const {'profile_status': 'pending_review'},
        outputs: const [],
        candidates: const [],
        suggestions: const [],
      ),
      isEmpty,
    );
  });

  test('empty inputs produce no attention', () {
    expect(
      attentionItems(
        person: const {},
        outputs: const [],
        candidates: const [],
        suggestions: const [],
      ),
      isEmpty,
    );
  });

  test('pending proposals count only researcher suggestions', () {
    expect(
      pendingProposals(const [
        {'status': 'pending', 'source': 'researcher'},
        {'status': 'pending', 'source': 'researcher'},
        {'status': 'rejected', 'source': 'researcher'},
        {'status': 'pending', 'source': 'admin'},
      ]),
      2,
    );
  });
}
