import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/chart_palette.dart';
import '../widgets/stat_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _year; // null = all-time
  final Future<List<int>> _years = fetchDistinctYears();
  late Future<_DashboardData> _data = _loadDashboard();

  void _setYear(int? year) => setState(() {
    _year = year;
    _data = _loadDashboard();
  });

  Future<_DashboardData> _loadDashboard() async {
    final rows = await Future.wait([
      fetchPeopleForStats(),
      fetchOutputsForStats(),
      fetchAuthorCounts(),
    ]);
    final counts = await Future.wait([
      fetchCount('labs'),
      fetchCount('projects'),
      fetchCount('clusters'),
    ]);
    final byCluster = await fetchProjectLinkCounts(
      'project_clusters',
      'clusters',
    );
    final byLab = await fetchProjectLinkCounts('project_labs', 'labs');
    final labAllocations = _year == null
        ? await fetchCount('lab_members')
        : await countRowsForYear('lab_members', _year!);
    final mentorships = _year == null
        ? await fetchCount('mentorships')
        : await countRowsForYear('mentorships', _year!);
    return _DashboardData.fromRows(
      rows[0],
      rows[1],
      rows[2],
      year: _year,
      labCount: counts[0],
      projectCount: counts[1],
      clusterCount: counts[2],
      projectsByCluster: byCluster,
      projectsByLab: byLab,
      labAllocations: labAllocations,
      mentorships: mentorships,
    );
  }

  Widget _yearSelector() {
    return FutureBuilder<List<int>>(
      future: _years,
      builder: (context, snapshot) {
        final years = (snapshot.data ?? [])..sort((a, b) => b.compareTo(a));
        return Row(
          children: [
            Text('Year', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 12),
            DropdownButton<int?>(
              value: _year,
              items: [
                const DropdownMenuItem(value: null, child: Text('All-time')),
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: _setYear,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _yearSelector(),
              const SizedBox(height: 12),
              _StatTilesRow(data: data),
              const SizedBox(height: 16),
              _ResponsiveCharts(data: data),
            ],
          ),
        );
      },
    );
  }
}

class _StatTilesRow extends StatelessWidget {
  const _StatTilesRow({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatTile(
        label: 'Researchers',
        value: '${data.peopleCount}',
        icon: Icons.people,
      ),
      StatTile(
        label: 'Outputs',
        value: '${data.outputCount}',
        icon: Icons.article,
      ),
      StatTile(
        label: 'Journal articles',
        value: '${data.journalCount}',
        icon: Icons.library_books,
      ),
      StatTile(
        label: 'Needs verification',
        value: '${data.needsVerification}',
        icon: Icons.verified_outlined,
      ),
      StatTile(
        label: 'Missing ORCID',
        value: '${data.missingOrcid}',
        icon: Icons.badge_outlined,
      ),
      StatTile(
        label: 'Labs',
        value: '${data.labCount}',
        icon: Icons.science_outlined,
      ),
      StatTile(
        label: 'Projects',
        value: '${data.projectCount}',
        icon: Icons.work_outline,
      ),
      StatTile(
        label: 'Clusters',
        value: '${data.clusterCount}',
        icon: Icons.hub_outlined,
      ),
      StatTile(
        label: 'Verified outputs',
        value: '${data.verifiedOutputs}',
        icon: Icons.verified_outlined,
      ),
      StatTile(
        label: data.year == null ? 'Lab allocations' : 'Lab allocations ${data.year}',
        value: '${data.labAllocations}',
        icon: Icons.science_outlined,
      ),
      StatTile(
        label: data.year == null ? 'Mentorships' : 'Mentorships ${data.year}',
        value: '${data.mentorships}',
        icon: Icons.school_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                SizedBox(width: 150, child: tiles[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ResponsiveCharts extends StatelessWidget {
  const _ResponsiveCharts({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final children = [
          _ChartCard(
            title: 'Outputs by type',
            bounded: false,
            child: _HorizontalBars(items: data.outputsByType),
          ),
          _ChartCard(
            title: 'Journal articles by quartile',
            child: _QuartileChart(counts: data.journalsByQuartile),
          ),
          _ChartCard(
            title: 'Top 10 researchers by output count',
            bounded: false,
            child: _HorizontalBars(items: data.topResearchers),
          ),
          _ChartCard(
            title: 'People by category',
            child: _MembershipChart(items: data.membershipCounts),
          ),
          _ChartCard(
            title: 'Projects by cluster',
            bounded: false,
            child: _HorizontalBars(items: data.projectsByCluster),
          ),
          _ChartCard(
            title: 'Projects by lab',
            bounded: false,
            child: _HorizontalBars(items: data.projectsByLab),
          ),
        ];
        if (!wide) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: 16),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final child in children)
              SizedBox(width: (constraints.maxWidth - 16) / 2, child: child),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.bounded = true,
  });

  final String title;
  final Widget child;
  final bool bounded;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (bounded) SizedBox(height: 280, child: child) else child,
          ],
        ),
      ),
    );
  }
}

class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars({required this.items});

  final List<_CountItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('No data'));
    final theme = Theme.of(context);
    final color = slotColor(1, theme.brightness);
    final max = items.map((item) => item.count).reduce((a, b) => a > b ? a : b);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          SizedBox(
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 190,
                  child: Tooltip(
                    message: item.label,
                    child: Text(
                      _shortLabel(item.label),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: item.count / max,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${item.count}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

const _shortOutputTypeLabels = {
  'Actividades de gestão e auxílio à UNIDCOM': 'Gestão & apoio UNIDCOM',
  'Organização de Seminários e Conferências': 'Seminários & conferências',
  'Valorizações de atividades ou outros outputs no âmbito de projetos científicos':
      'Valorizações de projetos',
  'Participação em projectos de investigação': 'Participação em projetos',
  'Reconhecimento pela comunidade científica': 'Reconhecimento científico',
  'Missões de internacionalização no âmbito de projetos científicos':
      'Missões de internacionalização',
  'Conferência em congressos (sem publicação)': 'Conferências (sem publicação)',
};

String _shortLabel(String label) => _shortOutputTypeLabels[label] ?? label;

class _QuartileChart extends StatelessWidget {
  const _QuartileChart({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = slotColor(1, theme.brightness);
    final textColor = theme.textTheme.bodySmall?.color;
    final labels = ['Q1', 'Q2', 'Q3', 'Q4'];
    final max = labels
        .map((label) => counts[label] ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    if (max == 0) return const Center(child: Text('No journal quartile data'));
    return BarChart(
      BarChartData(
        maxY: max * 1.2,
        barGroups: [
          for (var i = 0; i < labels.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (counts[labels[i]] ?? 0).toDouble(),
                  width: 18,
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.35),
            strokeWidth: 0.8,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: theme.textTheme.bodySmall?.copyWith(color: textColor),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${labels[i]}\n${counts[labels[i]] ?? 0}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }
}

class _MembershipChart extends StatelessWidget {
  const _MembershipChart({required this.items});

  final List<_CountItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('No membership data'));
    final theme = Theme.of(context);
    final total = items.fold(0, (sum, item) => sum + item.count);
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 46,
              sectionsSpace: 2,
              sections: [
                for (var i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: items[i].count.toDouble(),
                    title: '${items[i].count}',
                    color: slotColor(i + 1, theme.brightness),
                    radius: 58,
                    titleStyle: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: slotColor(i + 1, theme.brightness),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${items[i].label} — ${items[i].count}'
                          ' (${(items[i].count * 100 / total).round()}%)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.year,
    required this.peopleCount,
    required this.outputCount,
    required this.journalCount,
    required this.needsVerification,
    required this.missingOrcid,
    required this.labCount,
    required this.projectCount,
    required this.clusterCount,
    required this.verifiedOutputs,
    required this.labAllocations,
    required this.mentorships,
    required this.outputsByType,
    required this.journalsByQuartile,
    required this.topResearchers,
    required this.membershipCounts,
    required this.projectsByCluster,
    required this.projectsByLab,
  });

  final int? year;
  final int peopleCount;
  final int outputCount;
  final int journalCount;
  final int needsVerification;
  final int missingOrcid;
  final int labCount;
  final int projectCount;
  final int clusterCount;
  final int verifiedOutputs;
  final int labAllocations;
  final int mentorships;
  final List<_CountItem> outputsByType;
  final Map<String, int> journalsByQuartile;
  final List<_CountItem> topResearchers;
  final List<_CountItem> membershipCounts;
  final List<_CountItem> projectsByCluster;
  final List<_CountItem> projectsByLab;

  factory _DashboardData.fromRows(
    List<Map<String, dynamic>> people,
    List<Map<String, dynamic>> allOutputs,
    List<Map<String, dynamic>> authors, {
    int? year,
    required int labCount,
    required int projectCount,
    required int clusterCount,
    required Map<String, int> projectsByCluster,
    required Map<String, int> projectsByLab,
    required int labAllocations,
    required int mentorships,
  }) {
    // Output-based stats respect the selected year (outputs carry reporting_year).
    final outputs = year == null
        ? allOutputs
        : allOutputs.where((o) => o['reporting_year'] == year).toList();
    final cutoff = DateTime.now().subtract(const Duration(days: 183));
    final journalOutputs = outputs.where(_isJournal).toList();
    final quartiles = {
      for (final q in ['Q1', 'Q2', 'Q3', 'Q4']) q: 0,
    };
    for (final output in journalOutputs) {
      final match = RegExp(
        r'quartil\s*q([1-4])|q([1-4])',
        caseSensitive: false,
      ).firstMatch(output['subtype'] as String? ?? '');
      final q = match?.group(1) ?? match?.group(2);
      if (q != null) quartiles['Q$q'] = quartiles['Q$q']! + 1;
    }

    return _DashboardData(
      year: year,
      peopleCount: people.length,
      outputCount: outputs.length,
      journalCount: journalOutputs.length,
      needsVerification: people.where((person) {
        final value = person['last_verified_at'] as String?;
        if (value == null) return true;
        return DateTime.tryParse(value)?.isBefore(cutoff) ?? true;
      }).length,
      missingOrcid: people.where((person) {
        final value = (person['orcid'] as String?)?.trim();
        return value == null || value.isEmpty;
      }).length,
      labCount: labCount,
      projectCount: projectCount,
      clusterCount: clusterCount,
      labAllocations: labAllocations,
      mentorships: mentorships,
      verifiedOutputs: outputs.where((o) => o['verified_online'] == true).length,
      outputsByType: _topWithOther(_countBy(outputs, (row) => _type(row))),
      journalsByQuartile: quartiles,
      topResearchers: _topResearchers(authors),
      membershipCounts: _membershipCounts(people),
      projectsByCluster: _mapToItems(projectsByCluster),
      projectsByLab: _mapToItems(projectsByLab),
    );
  }
}

List<_CountItem> _mapToItems(Map<String, int> counts) {
  final items =
      counts.entries.map((e) => _CountItem(e.key, e.value)).toList()
        ..sort((a, b) => b.count.compareTo(a.count));
  return items;
}

class _CountItem {
  const _CountItem(this.label, this.count);

  final String label;
  final int count;
}

bool _isJournal(Map<String, dynamic> output) {
  return _type(output).toLowerCase().contains('artigos em revistas');
}

String _type(Map<String, dynamic> output) {
  final value = (output['type'] as String?)?.trim();
  return value == null || value.isEmpty ? 'Unknown' : value;
}

Map<String, int> _countBy(
  List<Map<String, dynamic>> rows,
  String Function(Map<String, dynamic>) keyOf,
) {
  final counts = <String, int>{};
  for (final row in rows) {
    counts.update(keyOf(row), (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

List<_CountItem> _topWithOther(Map<String, int> counts) {
  final items =
      counts.entries.map((entry) => _CountItem(entry.key, entry.value)).toList()
        ..sort((a, b) => b.count.compareTo(a.count));
  if (items.length <= 8) return items;
  final other = items.skip(8).fold(0, (sum, item) => sum + item.count);
  return [...items.take(8), _CountItem('Other', other)];
}

List<_CountItem> _topResearchers(List<Map<String, dynamic>> authors) {
  final counts = <String, int>{};
  for (final author in authors) {
    final person = author['people'] as Map<String, dynamic>?;
    final name = person?['preferred_name'] as String?;
    if (name != null) {
      counts.update(name, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  final items =
      counts.entries.map((entry) => _CountItem(entry.key, entry.value)).toList()
        ..sort((a, b) => b.count.compareTo(a.count));
  return items.take(10).toList();
}

// One place to re-map when the authoritative categories arrive from the boss.
const _categoryLabels = {
  'integrated': 'Integrated members',
  'collaborator': 'Collaborators',
  'phd_student': 'PhD students',
  'external': 'External',
  'advisory_board': 'Advisory board',
  'staff': 'Staff',
};

List<_CountItem> _membershipCounts(List<Map<String, dynamic>> people) {
  final counts = _countBy(
    people,
    (row) => row['membership_type'] as String? ?? '',
  );
  var other = 0;
  final items = <_CountItem>[];
  counts.forEach((key, count) {
    final label = _categoryLabels[key];
    if (label == null) {
      other += count; // null / unknown enum values
    } else {
      items.add(_CountItem(label, count));
    }
  });
  if (other > 0) items.add(_CountItem('Other', other));
  items.sort((a, b) => b.count.compareTo(a.count));
  return items;
}
