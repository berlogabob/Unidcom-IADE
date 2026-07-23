import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/enrich_client.dart';

void main() {
  group('cienciaIdFromOrcidPerson', () {
    test('extracts value when a CiênciaVitae identifier is present', () {
      final profile = {
        'external-identifiers': {
          'external-identifier': [
            {'external-id-type': 'Scopus Author ID', 'external-id-value': '123'},
            {'external-id-type': 'CienciaID', 'external-id-value': '5D19-A8B4-0000'},
          ],
        },
      };
      expect(cienciaIdFromOrcidPerson(profile), '5D19-A8B4-0000');
    });

    test('matches by URL host when type is generic', () {
      final profile = {
        'external-identifiers': {
          'external-identifier': [
            {
              'external-id-type': 'other',
              'external-id-value': 'ABCD-1234-5678',
              'external-id-url': {'value': 'https://cienciavitae.pt/portal/ABCD'},
            },
          ],
        },
      };
      expect(cienciaIdFromOrcidPerson(profile), 'ABCD-1234-5678');
    });

    test('returns null when absent', () {
      final profile = {
        'external-identifiers': {
          'external-identifier': [
            {'external-id-type': 'Scopus Author ID', 'external-id-value': '123'},
          ],
        },
      };
      expect(cienciaIdFromOrcidPerson(profile), isNull);
    });
  });

  group('orcidPersonValues', () {
    test('extracts bio, ciencia_id, ranked email and legal name', () {
      final profile = {
        'biography': {'content': 'IADE UNIDCOM updated bio to test'},
        'external-identifiers': {
          'external-identifier': [
            {'external-id-type': 'CienciaID', 'external-id-value': 'E018-7F41-627B'},
          ],
        },
        'emails': {
          'email': [
            {'email': 'other@x.pt', 'primary': false, 'verified': false},
            {'email': '20251186@iade.pt', 'primary': true, 'verified': true},
          ],
        },
        'name': {
          'given-names': {'value': 'Andrey'},
          'family-name': {'value': 'Dyakov'},
        },
      };
      final values = orcidPersonValues(profile);
      expect(values['bio'], 'IADE UNIDCOM updated bio to test');
      expect(values['ciencia_id'], 'E018-7F41-627B');
      expect(values['email'], '20251186@iade.pt'); // primary+verified ranked first
      expect(values['legal_name'], 'Andrey Dyakov');
    });

    test('omits fields absent from the profile', () {
      expect(orcidPersonValues({'name': {}}), isEmpty);
    });
  });

  group('pickOrcidCandidate', () {
    Map<String, dynamic> result(String orcid, String given, String family,
            [List<String>? orgs]) =>
        {
          'orcid-id': orcid,
          'given-names': given,
          'family-names': family,
          'institution-name': orgs ?? const [],
        };

    test('picks the IADE-affiliated homonym at 0.7', () {
      final results = [
        result('0000-0001-0000-0001', 'Ana', 'Silva', ['Some University']),
        result('0000-0002-0000-0002', 'Ana', 'Silva', ['IADE, Universidade Europeia']),
      ];
      final picked = pickOrcidCandidate(results, 'Ana Silva');
      expect(picked?.orcid, '0000-0002-0000-0002');
      expect(picked?.confidence, 0.7);
    });

    test('picks IADE by full legal name over a same-name homonym', () {
      final results = [
        result('0000-0002-1994-3944', 'Andrey', 'Dyakov',
            ['Mining Institute of the Kola Science Centre']),
        result('0009-0009-8585-0074', 'Andrey', 'Dyakov',
            ['Instituto de Artes Visuais, Design e Marketing']),
      ];
      final picked = pickOrcidCandidate(results, 'Andrey Dyakov');
      expect(picked?.orcid, '0009-0009-8585-0074');
      expect(picked?.confidence, 0.7);
    });

    test('lone name match at 0.5', () {
      final results = [result('0000-0003-0000-0003', 'Bruno', 'Costa')];
      final picked = pickOrcidCandidate(results, 'Bruno Costa');
      expect(picked?.orcid, '0000-0003-0000-0003');
      expect(picked?.confidence, 0.5);
    });

    test('ambiguous same-name with no institution signal -> null', () {
      final results = [
        result('0000-0004-0000-0004', 'Ana', 'Silva'),
        result('0000-0005-0000-0005', 'Ana', 'Silva'),
      ];
      expect(pickOrcidCandidate(results, 'Ana Silva'), isNull);
    });

    test('no name match -> null', () {
      final results = [result('0000-0006-0000-0006', 'Carlos', 'Dias')];
      expect(pickOrcidCandidate(results, 'Ana Silva'), isNull);
    });
  });
}
