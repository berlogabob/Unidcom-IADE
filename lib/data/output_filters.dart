/// D5-A output filters, counts and grouping (Rui, 10 Sep 2026, §9–§12).
/// Widgets render, this file decides.
library;

import 'taxonomy.dart';

enum OutputView { all, recent, featured, attention, orcid }

enum OutputGroup { year, type, project }

const _unset = Object();

class OutputFilter {
  const OutputFilter({
    this.query = '',
    this.year,
    this.category = const [],
    this.projectId,
    this.review,
    this.website,
    this.featuredOnly = false,
    this.issuesOnly = false,
    this.kind,
    this.affiliation,
    this.view = OutputView.all,
  });

  final String query;
  final int? year;
  final List<String> category;
  final String? projectId;
  final String? review;
  final String? website;
  final bool featuredOnly;
  final bool issuesOnly;
  final String? kind;

  /// null = all, 'unidcom' = affiliated, 'external' = not affiliated.
  final String? affiliation;
  final OutputView view;

  OutputFilter copyWith({
    String? query,
    Object? year = _unset,
    Object? category = _unset,
    Object? projectId = _unset,
    Object? review = _unset,
    Object? website = _unset,
    bool? featuredOnly,
    Object? issuesOnly = _unset,
    Object? kind = _unset,
    Object? affiliation = _unset,
    OutputView? view,
  }) => OutputFilter(
    query: query ?? this.query,
    year: identical(year, _unset) ? this.year : year as int?,
    category: identical(category, _unset)
        ? this.category
        : category as List<String>,
    projectId: identical(projectId, _unset)
        ? this.projectId
        : projectId as String?,
    review: identical(review, _unset) ? this.review : review as String?,
    website: identical(website, _unset) ? this.website : website as String?,
    featuredOnly: featuredOnly ?? this.featuredOnly,
    issuesOnly: identical(issuesOnly, _unset)
        ? this.issuesOnly
        : issuesOnly as bool,
    kind: identical(kind, _unset) ? this.kind : kind as String?,
    affiliation: identical(affiliation, _unset)
        ? this.affiliation
        : affiliation as String?,
    view: view ?? this.view,
  );
}

String? rootOf(Map<String, dynamic> output) {
  final path = output['category_path'];
  return categorySegments(path is String ? path : null).firstOrNull;
}

/// English display names for the PT taxonomy roots (Rui, 1 Oct: the UI is in
/// English). Data and filter values stay PT; only the label changes.
const rootLabelsEn = {
  'Actividades de gestão e auxílio à UNIDCOM':
      'UNIDCOM management and support activities',
  'Artigos em revistas': 'Journal articles',
  'Conferência em congressos (sem publicação)':
      'Conference presentations (unpublished)',
  'Formação avançada': 'Advanced training',
  'Livros': 'Books',
  'Missões de internacionalização no âmbito de projetos científicos':
      'International missions in scientific projects',
  'Organização de Seminários e Conferências':
      'Seminar and conference organisation',
  'Participação em projectos de investigação':
      'Participation in research projects',
  'Patentes e contratos industriais': 'Patents and industrial contracts',
  'Reconhecimento pela comunidade científica':
      'Recognition by the scientific community',
  'Valorizações de atividades ou outros outputs no âmbito de projetos científicos':
      'Valorisation of activities and outputs in scientific projects',
};

String rootLabel(String root) => rootLabelsEn[root] ?? root;

/// Roots that are not scientific outputs (Rui, 1 Oct; DOC 2 §K): kept out of
/// Scientific Outputs and the Overview counts.
const hiddenRoots = {
  'Actividades de gestão e auxílio à UNIDCOM',
  'Missões de internacionalização no âmbito de projetos científicos',
};

bool isScientificOutput(Map<String, dynamic> output) =>
    !hiddenRoots.contains(rootOf(output));

/// ORCID work types that are publications in Rui's sense (journal articles,
/// conference papers, books, book chapters).
const orcidPublicationTypes = {
  'journal-article',
  'conference-paper',
  'book',
  'book-chapter',
};

/// 'publication' or 'activity'. From the taxonomy root when the output is
/// classified; otherwise from its ORCID work type, so unclassified ORCID
/// imports still land in a tab (30 Sep: 5 outputs had no category).
String kindOf(Map<String, dynamic> output, Map<String, String> kindByRoot) =>
    kindByRoot[rootOf(output)] ??
    (orcidPublicationTypes.contains(output['type'])
        ? 'publication'
        : 'activity');

List<Map<String, dynamic>> filterOutputs(
  List<Map<String, dynamic>> outputs,
  OutputFilter filter, {
  Set<String> featuredIds = const {},
  Map<String, String> kindByRoot = const {},
}) {
  final query = filter.query.toLowerCase();
  final filtered = outputs.where((output) {
    final title = output['title']?.toString().toLowerCase() ?? '';
    final doi = output['doi']?.toString().toLowerCase() ?? '';
    final projects = output['project_outputs'];
    final hasProject =
        projects is List &&
        projects.any((link) {
          final project = link is Map ? link['projects'] : null;
          return project is Map &&
              project['id']?.toString() == filter.projectId;
        });
    final website = output['website_status'] ?? 'not_published';
    final id = output['id']?.toString();
    final matchesView = switch (filter.view) {
      OutputView.all ||
      OutputView.recent ||
      OutputView.featured ||
      OutputView.attention ||
      OutputView.orcid => true,
    };
    return (query.isEmpty || title.contains(query) || doi.contains(query)) &&
        (filter.year == null || output['reporting_year'] == filter.year) &&
        matchesCategory(output['category_path'] as String?, filter.category) &&
        (filter.projectId == null || hasProject) &&
        (filter.review == null || output['approval_status'] == filter.review) &&
        (filter.website == null || website == filter.website) &&
        (!filter.featuredOnly || featuredIds.contains(id)) &&
        (!filter.issuesOnly || hasIssues(output)) &&
        (filter.kind == null || kindOf(output, kindByRoot) == filter.kind) &&
        (filter.affiliation == null ||
            (output['affiliation'] ?? 'unidcom') == filter.affiliation) &&
        matchesView;
  }).toList();

  final view = filter.view;
  if (view == OutputView.featured) {
    filtered.removeWhere(
      (output) => !featuredIds.contains(output['id']?.toString()),
    );
  } else if (view == OutputView.attention) {
    filtered.removeWhere(
      (output) =>
          (output['error_count'] ?? 0) <= 0 &&
          (output['warning_count'] ?? 0) <= 0 &&
          output['approval_status'] != 'rejected',
    );
  } else if (view == OutputView.orcid) {
    filtered.removeWhere((output) => output['source'] != 'orcid');
  }
  if (view == OutputView.all) return filtered;
  filtered.sort(_outputOrder);
  return view == OutputView.recent ? filtered.take(5).toList() : filtered;
}

int _outputOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
  final ay = a['reporting_year'] as int?;
  final by = b['reporting_year'] as int?;
  if (ay != by) {
    if (ay == null) return 1;
    if (by == null) return -1;
    return by.compareTo(ay);
  }
  return (a['title']?.toString() ?? '').compareTo(b['title']?.toString() ?? '');
}

Map<String, int> countByType(List<Map<String, dynamic>> outputs) {
  final counts = <String, int>{};
  for (final output in outputs) {
    final label = rootOf(output) ?? 'Unclassified';
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort(
      (a, b) => b.value.compareTo(a.value) == 0
          ? a.key.compareTo(b.key)
          : b.value.compareTo(a.value),
    );
  return Map.fromEntries(entries);
}

Map<String, List<Map<String, dynamic>>> groupOutputs(
  List<Map<String, dynamic>> outputs,
  OutputGroup by,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final output in outputs) {
    final keys = switch (by) {
      OutputGroup.year => [
        (output['reporting_year'] as int?)?.toString() ?? 'Undated',
      ],
      OutputGroup.type => [rootOf(output) ?? 'Unclassified'],
      OutputGroup.project =>
        _projectEntries(output).isEmpty
            ? ['No project']
            : _projectEntries(output).map((project) => project.title).toList(),
    };
    for (final key in keys) {
      groups.putIfAbsent(key, () => []).add(output);
    }
  }
  final keys = groups.keys.toList()
    ..sort(
      (a, b) => switch (by) {
        OutputGroup.year => _yearKey(b).compareTo(_yearKey(a)),
        OutputGroup.type =>
          groups[b]!.length.compareTo(groups[a]!.length) == 0
              ? a.compareTo(b)
              : groups[b]!.length.compareTo(groups[a]!.length),
        OutputGroup.project =>
          a == 'No project'
              ? 1
              : b == 'No project'
              ? -1
              : a.compareTo(b),
      },
    );
  return {for (final key in keys) key: groups[key]!};
}

int _yearKey(String value) => value == 'Undated' ? -1 : int.parse(value);

List<({String id, String title})> _projectEntries(
  Map<String, dynamic> output,
) => [
  for (final link
      in (output['project_outputs'] is List)
          ? output['project_outputs'] as List
          : const [])
    if (link is Map &&
        link['projects'] is Map &&
        link['projects']['id'] != null &&
        link['projects']['title'] != null)
      (
        id: link['projects']['id'].toString(),
        title: link['projects']['title'].toString(),
      ),
];

List<int> yearsOf(List<Map<String, dynamic>> outputs) => {
  for (final output in outputs)
    if (output['reporting_year'] is int) output['reporting_year'] as int,
}.toList()..sort((a, b) => b.compareTo(a));

bool hasIssues(Map<String, dynamic> output) =>
    ((output['error_count'] as int?) ?? 0) > 0 ||
    ((output['warning_count'] as int?) ?? 0) > 0;

/// '12 outputs · 3 Livros · 9 Artigos em revistas · 2 with issues' — for whatever rows it is given.
String countsLine(List<Map<String, dynamic>> rows) {
  final parts = ['${rows.length} ${rows.length == 1 ? 'output' : 'outputs'}'];
  for (final entry in countByType(rows).entries) {
    final count = entry.value;
    final label = rootLabel(entry.key);
    parts.add('$count $label');
  }
  final n = rows.where(hasIssues).length;
  if (n > 0) {
    parts.add('$n with issues');
  }
  return parts.join(' · ');
}

List<({String id, String title})> projectsOf(
  List<Map<String, dynamic>> outputs,
) {
  final projects = <String, ({String id, String title})>{};
  for (final output in outputs) {
    for (final project in _projectEntries(output)) {
      projects['${project.id}\u0000${project.title}'] = project;
    }
  }
  return projects.values.toList()..sort((a, b) {
    final title = a.title.compareTo(b.title);
    return title == 0 ? a.id.compareTo(b.id) : title;
  });
}
