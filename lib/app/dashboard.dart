import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/chart_palette.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

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
    final stats = await Future.wait<Object>([
      fetchPeopleForStats(),
      fetchOutputsForStats(),
      fetchAuthorCounts(),
      fetchPilotKpis(),
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
    final mentorships = await countRoles('mentorship', year: _year);
    // For a selected year, membership comes from the roles logbook (a person can
    // be integrated one year, external the next); all-time uses the current cache.
    final membershipByYear = _year == null
        ? null
        : await fetchMembershipByYear(_year!);
    return _DashboardData.fromRows(
      stats[0] as List<Map<String, dynamic>>,
      stats[1] as List<Map<String, dynamic>>,
      stats[2] as List<Map<String, dynamic>>,
      year: _year,
      pilotKpis: stats[3] as Map<String, int>,
      labCount: counts[0],
      projectCount: counts[1],
      clusterCount: counts[2],
      projectsByCluster: byCluster,
      projectsByLab: byLab,
      labAllocations: labAllocations,
      mentorships: mentorships,
      membershipByYear: membershipByYear,
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
    return AsyncView<_DashboardData>(
      future: _data,
      builder: (context, data) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _yearSelector(),
              const SizedBox(height: 12),
              _StatTilesRow(data: data, pilot: true),
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
  const _StatTilesRow({required this.data, this.pilot = false});

  final _DashboardData data;
  final bool pilot;

  @override
  Widget build(BuildContext context) {
    if (pilot) {
      return _buildTiles([
        AccentStatCard(
          label: 'ORCID linked',
          value:
              '${data.pilotKpis['orcidLinked']} / ${data.pilotKpis['people']}',
          tone: AccentTone.good,
        ),
        AccentStatCard(
          label: 'Profiles validated',
          value:
              '${data.pilotKpis['profilesValidated']} / ${data.pilotKpis['people']}',
          tone: AccentTone.good,
        ),
        AccentStatCard(
          label: 'Outputs approved',
          value:
              '${data.pilotKpis['outputsApproved']} / ${data.pilotKpis['outputs']}',
          tone: AccentTone.good,
        ),
        AccentStatCard(
          label: 'DOI coverage',
          value:
              '${data.pilotKpis['doiCoverage']} / ${data.pilotKpis['outputs']}',
          tone: AccentTone.good,
        ),
      ]);
    }
    final tiles = [
      AccentStatCard(label: 'Researchers', value: '${data.peopleCount}'),
      AccentStatCard(
        label: 'Outputs',
        value: '${data.outputCount}',
        tone: AccentTone.good,
      ),
      AccentStatCard(
        label: 'Journal articles',
        value: '${data.journalCount}',
        tone: AccentTone.info,
      ),
      AccentStatCard(
        label: 'Needs verification',
        value: '${data.needsVerification}',
        tone: AccentTone.urgent,
      ),
      AccentStatCard(
        label: 'Missing ORCID',
        value: '${data.missingOrcid}',
        tone: AccentTone.urgent,
      ),
      AccentStatCard(label: 'Labs', value: '${data.labCount}'),
      AccentStatCard(
        label: 'Projects',
        value: '${data.projectCount}',
        tone: AccentTone.info,
      ),
      AccentStatCard(label: 'Clusters', value: '${data.clusterCount}'),
      AccentStatCard(
        label: 'Verified outputs',
        value: '${data.verifiedOutputs}',
        tone: AccentTone.good,
      ),
      AccentStatCard(
        label: data.year == null
            ? 'Lab allocations'
            : 'Lab allocations ${data.year}',
        value: '${data.labAllocations}',
        tone: AccentTone.info,
      ),
      AccentStatCard(
        label: data.year == null ? 'Mentorships' : 'Mentorships ${data.year}',
        value: '${data.mentorships}',
      ),
    ];

    return _buildTiles(tiles);
  }

  Widget _buildTiles(List<AccentStatCard> tiles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          final columns = tiles.length < 6 ? tiles.length : 6;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final tile in tiles) SizedBox(width: width, child: tile),
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
          Panel(
            title: 'Outputs by type',
            child: _HorizontalBars(
              items: data.outputsByType,
              color: AppColors.teal,
            ),
          ),
          Panel(
            title: 'Journal articles by quartile',
            child: SizedBox(
              height: 280,
              child: _QuartileChart(counts: data.journalsByQuartile),
            ),
          ),
          Panel(
            title: 'Top 10 researchers by output count',
            child: _HorizontalBars(
              items: data.topResearchers,
              color: AppColors.blue,
            ),
          ),
          Panel(
            title: 'People by category',
            child: SizedBox(
              height: 280,
              child: _MembershipChart(items: data.membershipCounts),
            ),
          ),
          Panel(
            title: 'Projects by cluster',
            child: _HorizontalBars(
              items: data.projectsByCluster,
              color: AppColors.teal,
            ),
          ),
          Panel(
            title: 'Projects by lab',
            child: _HorizontalBars(
              items: data.projectsByLab,
              color: AppColors.blue,
            ),
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

class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars({required this.items, required this.color});

  final List<_CountItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('No data'));
    final max = items.map((item) => item.count).reduce((a, b) => a > b ? a : b);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: item.label,
                        child: Text(
                          _shortLabel(item.label),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.count}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.sandHoverStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: item.count / max,
                    heightFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
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
    required this.pilotKpis,
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
  final Map<String, int> pilotKpis;
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
    required Map<String, int> pilotKpis,
    required int labCount,
    required int projectCount,
    required int clusterCount,
    required Map<String, int> projectsByCluster,
    required Map<String, int> projectsByLab,
    required int labAllocations,
    required int mentorships,
    Map<String, int>? membershipByYear,
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
      pilotKpis: pilotKpis,
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
      verifiedOutputs: outputs
          .where((o) => o['verified_online'] == true)
          .length,
      outputsByType: _topWithOther(_countBy(outputs, (row) => _type(row))),
      journalsByQuartile: quartiles,
      topResearchers: _topResearchers(authors),
      membershipCounts: membershipByYear != null
          ? _membershipItems(membershipByYear)
          : _membershipCounts(people),
      projectsByCluster: _mapToItems(projectsByCluster),
      projectsByLab: _mapToItems(projectsByLab),
    );
  }
}

List<_CountItem> _mapToItems(Map<String, int> counts) {
  final items = counts.entries.map((e) => _CountItem(e.key, e.value)).toList()
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

List<_CountItem> _membershipCounts(List<Map<String, dynamic>> people) =>
    _membershipItems(
      _countBy(people, (row) => row['membership_type'] as String? ?? ''),
    );

/// Maps a {membership_type: count} map to display items, using the canonical
/// [membershipLabels] (shared with the editor + logbook); unknowns → "Other".
List<_CountItem> _membershipItems(Map<String, int> counts) {
  var other = 0;
  final items = <_CountItem>[];
  counts.forEach((key, count) {
    final label = membershipLabels[key];
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
