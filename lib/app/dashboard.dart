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
  late final Future<_DashboardData> _data = _loadDashboard();

  Future<_DashboardData> _loadDashboard() async {
    final rows = await Future.wait([
      fetchPeopleForStats(),
      fetchOutputsForStats(),
      fetchAuthorCounts(),
    ]);
    return _DashboardData.fromRows(rows[0], rows[1], rows[2]);
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth < 700
                ? constraints.maxWidth
                : (constraints.maxWidth - 48) / 5;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _tile(
                        tileWidth,
                        'Researchers',
                        data.peopleCount,
                        Icons.people,
                      ),
                      _tile(
                        tileWidth,
                        'Outputs',
                        data.outputCount,
                        Icons.article,
                      ),
                      _tile(
                        tileWidth,
                        'Journal articles',
                        data.journalCount,
                        Icons.library_books,
                      ),
                      _tile(
                        tileWidth,
                        'Needs verification',
                        data.needsVerification,
                        Icons.verified_outlined,
                      ),
                      _tile(
                        tileWidth,
                        'Missing ORCID',
                        data.missingOrcid,
                        Icons.badge_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ResponsiveCharts(data: data),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _tile(double width, String label, int value, IconData icon) {
    return SizedBox(
      width: width,
      child: StatTile(label: label, value: '$value', icon: icon),
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
            child: _HorizontalBars(items: data.outputsByType),
          ),
          _ChartCard(
            title: 'Journal articles by quartile',
            child: _QuartileChart(counts: data.journalsByQuartile),
          ),
          _ChartCard(
            title: 'Top 10 researchers by output count',
            child: _HorizontalBars(items: data.topResearchers),
          ),
          _ChartCard(
            title: 'People by membership type',
            child: _MembershipChart(items: data.membershipCounts),
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
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
            SizedBox(height: 280, child: child),
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
      children: [
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
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
          ),
      ],
    );
  }
}

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
                          '${items[i].label} (${items[i].count})',
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
    required this.peopleCount,
    required this.outputCount,
    required this.journalCount,
    required this.needsVerification,
    required this.missingOrcid,
    required this.outputsByType,
    required this.journalsByQuartile,
    required this.topResearchers,
    required this.membershipCounts,
  });

  final int peopleCount;
  final int outputCount;
  final int journalCount;
  final int needsVerification;
  final int missingOrcid;
  final List<_CountItem> outputsByType;
  final Map<String, int> journalsByQuartile;
  final List<_CountItem> topResearchers;
  final List<_CountItem> membershipCounts;

  factory _DashboardData.fromRows(
    List<Map<String, dynamic>> people,
    List<Map<String, dynamic>> outputs,
    List<Map<String, dynamic>> authors,
  ) {
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
      outputsByType: _topWithOther(_countBy(outputs, (row) => _type(row))),
      journalsByQuartile: quartiles,
      topResearchers: _topResearchers(authors),
      membershipCounts: _membershipCounts(people),
    );
  }
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

List<_CountItem> _membershipCounts(List<Map<String, dynamic>> people) {
  const order = [
    'integrated',
    'collaborator',
    'external',
    'staff',
    'advisory_board',
  ];
  final counts = _countBy(
    people,
    (row) => row['membership_type'] as String? ?? '',
  );
  return [
    for (final key in order)
      if ((counts[key] ?? 0) > 0)
        _CountItem(key.replaceAll('_', ' '), counts[key]!),
  ];
}
