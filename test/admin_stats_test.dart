import 'package:unidcom_iade/data/admin_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminStats', () {
    test('members counts', () {
      final people = <Map<String, dynamic>>[
        {'membership_type': 'integrated', 'merged_into': null},
        {'membership_type': 'collaborator', 'merged_into': null},
        {'membership_type': 'integrated', 'merged_into': null},
        {'membership_type': 'external', 'merged_into': null},
        {'membership_type': 'integrated', 'merged_into': 'some_id'},
      ];
      final outputs = <Map<String, dynamic>>[];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {},
      );
      expect(result.integrated, 2);
      expect(result.collaborators, 1);
    });

    test('to-approve counts', () {
      final people = <Map<String, dynamic>>[
        {
          'membership_type': 'integrated',
          'profile_status': 'pending_review',
          'merged_into': null,
        },
        {
          'membership_type': 'integrated',
          'profile_status': 'approved',
          'merged_into': null,
        },
        {
          'membership_type': 'integrated',
          'profile_status': 'pending_review',
          'merged_into': null,
        },
      ];
      final outputs = <Map<String, dynamic>>[
        {'approval_status': 'pending', 'merged_into': null},
        {'approval_status': 'approved', 'merged_into': null},
        {'approval_status': 'pending', 'merged_into': null},
      ];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {},
      );
      expect(result.profilesToApprove, 2);
      expect(result.outputsToApprove, 2);
    });

    test('orcid linked counts', () {
      final people = <Map<String, dynamic>>[
        {'membership_type': 'integrated', 'orcid': '1234', 'merged_into': null},
        {'membership_type': 'integrated', 'orcid': '', 'merged_into': null},
        {'membership_type': 'integrated', 'orcid': null, 'merged_into': null},
        {'membership_type': 'integrated', 'orcid': '5678', 'merged_into': null},
      ];
      final outputs = <Map<String, dynamic>>[];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {},
      );
      expect(result.orcidLinked, 2);
      expect(result.orcidNotLinked, 2);
    });

    test('site visibility buckets', () {
      final people = <Map<String, dynamic>>[
        {
          'membership_type': 'integrated',
          'public_visibility': true,
          'profile_status': 'approved',
          'merged_into': null,
        },
        {
          'membership_type': 'integrated',
          'public_visibility': false,
          'profile_status': 'approved',
          'merged_into': null,
        },
        {
          'membership_type': 'integrated',
          'public_visibility': false,
          'profile_status': 'pending_review',
          'merged_into': null,
        },
        {
          'membership_type': 'integrated',
          'public_visibility': true,
          'profile_status': 'pending_review',
          'merged_into': null,
        },
        {
          'membership_type': 'integrated',
          'public_visibility': false,
          'profile_status': 'approved',
          'merged_into': null,
        },
      ];
      final outputs = <Map<String, dynamic>>[];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {},
      );
      expect(result.sitePublished, 2);
      expect(result.siteApprovedNotPublished, 2);
      expect(result.siteNotPublished, 1);
    });

    test('year filter', () {
      final people = <Map<String, dynamic>>[];
      final outputs = <Map<String, dynamic>>[
        {
          'membership_type': 'integrated',
          'reporting_year': 2023,
          'merged_into': null,
        },
        {
          'membership_type': 'integrated',
          'reporting_year': 2022,
          'merged_into': null,
        },
        {
          'membership_type': 'integrated',
          'reporting_year': 2023,
          'merged_into': null,
        },
      ];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {},
        year: 2023,
      );
      expect(result.outputsTotal, 2);
      expect(result.outputsByType['Other'], 2);
    });

    test('outputsByType with null->Other', () {
      final people = <Map<String, dynamic>>[];
      final outputs = <Map<String, dynamic>>[
        {'macro_type': 'Artigos em revistas', 'merged_into': null},
        {'macro_type': null, 'merged_into': null},
        {'macro_type': 'Livros', 'merged_into': null},
      ];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {},
      );
      expect(result.outputsByType['Artigos em revistas'], 1);
      expect(result.outputsByType['Other'], 1);
      expect(result.outputsByType['Livros'], 1);
    });

    test('missingDoi only for publications', () {
      final people = <Map<String, dynamic>>[];
      final outputs = <Map<String, dynamic>>[
        {'macro_type': 'Artigos em revistas', 'doi': null, 'merged_into': null},
        {'macro_type': 'Livros', 'doi': '', 'merged_into': null},
        {'macro_type': 'Other', 'doi': null, 'merged_into': null},
      ];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {},
      );
      expect(result.missingDoi, 2);
    });

    test('notOnOrcid respects orcidOutputIds and source', () {
      final people = <Map<String, dynamic>>[];
      final outputs = <Map<String, dynamic>>[
        {
          'macro_type': 'Artigos em revistas',
          'id': '1',
          'source': 'orcid',
          'merged_into': null,
        },
        {
          'macro_type': 'Artigos em revistas',
          'id': '2',
          'source': 'manual',
          'merged_into': null,
        },
        {
          'macro_type': 'Livros',
          'id': '3',
          'source': 'manual',
          'merged_into': null,
        },
        {
          'macro_type': 'Artigos em revistas',
          'id': '4',
          'source': 'manual',
          'merged_into': null,
        },
      ];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {'2', '3'},
      );
      expect(result.notOnOrcid, 1);
    });

    test('merged rows skipped', () {
      final people = <Map<String, dynamic>>[
        {'merged_into': 'some_id', 'membership_type': 'integrated'},
        {'merged_into': null, 'membership_type': 'integrated'},
        {'merged_into': null, 'membership_type': 'collaborator'},
      ];
      final outputs = <Map<String, dynamic>>[
        {'merged_into': 'some_id', 'approval_status': 'pending'},
        {'merged_into': null, 'approval_status': 'pending'},
        {'merged_into': null, 'approval_status': 'approved'},
      ];
      final result = computeAdminStats(
        people: people,
        outputs: outputs,
        orcidOutputIds: const {},
      );
      expect(result.integrated, 1);
      expect(result.collaborators, 1);
      expect(result.outputsToApprove, 1);
    });
  });
}
