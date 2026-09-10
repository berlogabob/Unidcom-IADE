import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/output_filters.dart';

void main() {
  final outputs = <Map<String, dynamic>>[
    {
      'id': '1',
      'title': 'Zeta Study',
      'reporting_year': 2025,
      'category_path': 'Research › Paper',
      'doi': '10/ZETA',
      'approval_status': 'approved',
      'website_status': 'published',
      'source': 'manual',
      'error_count': 0,
      'warning_count': 0,
      'project_outputs': [
        {
          'projects': {'id': 'p1', 'title': 'Alpha'},
        },
      ],
    },
    {
      'id': '2',
      'title': 'Alpha Activity',
      'reporting_year': 2024,
      'category_path': 'Teaching › Course',
      'doi': null,
      'approval_status': 'pending',
      'website_status': 'pending',
      'source': 'orcid',
      'issue_codes': ['w'],
      'error_count': 0,
      'warning_count': 1,
      'project_outputs': [
        {
          'projects': {'id': 'p1', 'title': 'Alpha'},
        },
        {
          'projects': {'id': 'p2', 'title': 'Beta'},
        },
      ],
    },
    {
      'id': '3',
      'title': 'Beta Paper',
      'reporting_year': 2023,
      'category_path': 'Research › Poster',
      'doi': '10/ZETA',
      'approval_status': 'rejected',
      'website_status': 'error',
      'source': 'manual',
      'error_count': 1,
      'warning_count': 0,
      'project_outputs': [],
    },
    {
      'id': '4',
      'title': 'No Date',
      'reporting_year': null,
      'category_path': null,
      'approval_status': 'approved',
      'source': 'import',
      'error_count': 0,
      'warning_count': 0,
    },
    {
      'id': '5',
      'title': 'Gamma',
      'reporting_year': 2022,
      'category_path': 'Research › Paper › Deep',
      'approval_status': 'approved',
      'error_count': 0,
      'warning_count': 0,
    },
    {
      'id': '6',
      'title': 'Delta',
      'reporting_year': 2021,
      'category_path': 'Other',
      'approval_status': 'approved',
      'website_status': 'not_published',
      'source': 'manual',
      'error_count': 0,
      'warning_count': 0,
    },
  ];

  test(
    'query matches title and doi, case-insensitive; empty query matches all',
    () {
      expect(
        filterOutputs(
          outputs,
          const OutputFilter(query: 'zEtA'),
        ).map((o) => o['id']),
        ['1', '3'],
      );
      expect(
        filterOutputs(
          outputs,
          const OutputFilter(query: '10/ZETA'),
        ).map((o) => o['id']),
        ['1', '3'],
      );
      expect(filterOutputs(outputs, const OutputFilter()).length, 6);
    },
  );
  test('field filters and taxonomy cascade', () {
    expect(
      filterOutputs(outputs, const OutputFilter(year: 2025)).single['id'],
      '1',
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(review: 'pending'),
      ).single['id'],
      '2',
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(website: 'not_published'),
      ).map((o) => o['id']),
      ['4', '5', '6'],
    );
    expect(
      filterOutputs(outputs, const OutputFilter(projectId: 'p2')).single['id'],
      '2',
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(featuredOnly: true),
        featuredIds: {'1', '5'},
      ).map((o) => o['id']),
      ['1', '5'],
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(kind: 'publication'),
        kindByRoot: {'Research': 'publication'},
      ).map((o) => o['id']),
      ['1', '3', '5'],
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(category: ['Research', 'Paper']),
      ).map((o) => o['id']),
      ['1', '5'],
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(category: []),
      ).map((o) => o['id']),
      ['1', '2', '3', '4', '5', '6'],
    );
  });
  test('each view; recent takes five and orders by year desc', () {
    expect(filterOutputs(outputs, const OutputFilter()).map((o) => o['id']), [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
    ]);
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(view: OutputView.recent),
      ).map((o) => o['id']),
      ['1', '2', '3', '5', '6'],
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(view: OutputView.featured),
        featuredIds: {'5', '1'},
      ).map((o) => o['id']),
      ['1', '5'],
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(view: OutputView.attention),
      ).map((o) => o['id']),
      ['2', '3'],
    );
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(view: OutputView.orcid),
      ).single['id'],
      '2',
    );
  });
  test('result ordering is year desc then title', () {
    expect(
      filterOutputs(
        outputs,
        const OutputFilter(view: OutputView.orcid),
      ).map((o) => o['title']),
      ['Alpha Activity'],
    );
  });
  test('countByType ordering and Unclassified', () {
    expect(countByType(outputs), {
      'Research': 3,
      'Other': 1,
      'Teaching': 1,
      'Unclassified': 1,
    });
  });
  test('groupOutputs groups years, types and projects', () {
    expect(groupOutputs(outputs, OutputGroup.year).keys, [
      '2025',
      '2024',
      '2023',
      '2022',
      '2021',
      'Undated',
    ]);
    expect(groupOutputs(outputs, OutputGroup.type).keys, [
      'Research',
      'Other',
      'Teaching',
      'Unclassified',
    ]);
    expect(groupOutputs(outputs, OutputGroup.project).keys, [
      'Alpha',
      'Beta',
      'No project',
    ]);
    expect(
      groupOutputs(outputs, OutputGroup.project)['Beta']!.single['id'],
      '2',
    );
    expect(
      groupOutputs(
        outputs,
        OutputGroup.project,
      )['No project']!.map((o) => o['id']),
      ['3', '4', '5', '6'],
    );
  });
  test('yearsOf and projectsOf are distinct and ordered', () {
    expect(yearsOf(outputs), [2025, 2024, 2023, 2022, 2021]);
    expect(projectsOf(outputs), [
      (id: 'p1', title: 'Alpha'),
      (id: 'p2', title: 'Beta'),
    ]);
  });
  test('copyWith clears a nullable field', () {
    expect(
      const OutputFilter(
        year: 2025,
        projectId: 'p1',
      ).copyWith(year: null, projectId: null).year,
      isNull,
    );
    expect(
      const OutputFilter(
        year: 2025,
        projectId: 'p1',
      ).copyWith(year: null, projectId: null).projectId,
      isNull,
    );
  });
}
