import 'package:flutter/material.dart';

import '../../data/attention.dart';
import '../../data/output_filters.dart';
import '../../data/status_labels.dart';
import '../../data/timeline.dart';
import '../../theme/tokens.dart';
import '../../widgets/ds_page.dart';
import '../../widgets/panels.dart';
import '../../widgets/timeline_bar.dart';

class OverviewView extends StatelessWidget {
  const OverviewView({
    super.key,
    required this.person,
    required this.alerts,
    required this.timeline,
    required this.outputs,
    required this.featuredCount,
    required this.onNavigate,
  });

  final Map<String, dynamic> person;
  final List<AttentionItem> alerts;
  final List<TimelineStep>? timeline;
  final List<Map<String, dynamic>> outputs;
  final int featuredCount;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final membership = switch (person['membership_type']) {
      'integrated' => 'Integrated researcher',
      'collaborator' => 'Collaborator',
      'external' => 'External researcher',
      _ => 'Researcher',
    };
    final name = person['preferred_name'] as String? ?? 'Researcher';

    return DsPage(
      title: name,
      subtitle: membership,
      children: [
        _Attention(alerts: alerts, onNavigate: onNavigate),
        if (timeline != null)
          Panel(
            title: 'Your record',
            child: TimelineBar(steps: timeline!),
          ),
        DsRow(
          left: _Bio(bio: person['bio'] as String?, onNavigate: onNavigate),
          right: _Summary(
            outputs: outputs,
            featuredCount: featuredCount,
            onNavigate: onNavigate,
          ),
        ),
        _RecentOutputs(outputs: outputs, onNavigate: onNavigate),
      ],
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.alerts, required this.onNavigate});

  final List<AttentionItem> alerts;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: alerts.isEmpty ? 'No action required' : 'Needs your attention',
      padding: EdgeInsets.zero,
      child: Material(
        color: AppColors.warnTint,
        child: Column(
          children: [
            for (var i = 0; i < alerts.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.amberDark,
                ),
                title: Text(alerts[i].text),
                onTap: () => onNavigate(alerts[i].route),
              ),
            ],
            if (alerts.isEmpty)
              const ListTile(
                leading: Icon(
                  Icons.check_circle_outline,
                  color: AppColors.tealDark,
                ),
                title: Text('Nothing needs your attention.'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bio extends StatelessWidget {
  const _Bio({required this.bio, required this.onNavigate});

  final String? bio;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final text = bio?.trim();
    return Panel(
      title: 'Bio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text == null || text.isEmpty)
            const Text('No biography yet')
          else
            Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
          TextButton(
            onPressed: () => onNavigate('/app/profile'),
            child: const Text('Edit bio →'),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.outputs,
    required this.featuredCount,
    required this.onNavigate,
  });

  final List<Map<String, dynamic>> outputs;
  final int featuredCount;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final counts = countByType(outputs);
    final issueCount = outputs.where(hasIssues).length;
    final links = [
      ('${outputs.length} outputs', '/app/outputs'),
      for (final entry in counts.entries)
        (
          '${entry.value} ${entry.key}',
          '/app/outputs?type=${Uri.encodeQueryComponent(entry.key)}',
        ),
      if (issueCount > 0) ('$issueCount with issues', '/app/outputs?issues=1'),
      ('Featured $featuredCount/5', '/app/outputs?view=featured'),
    ];

    return Panel(
      title: 'Summary',
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final link in links)
            TextButton(
              onPressed: () => onNavigate(link.$2),
              child: Text(link.$1),
            ),
        ],
      ),
    );
  }
}

class _RecentOutputs extends StatelessWidget {
  const _RecentOutputs({required this.outputs, required this.onNavigate});

  final List<Map<String, dynamic>> outputs;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final recent = [...outputs]
      ..sort(
        (a, b) => ((b['reporting_year'] as int?) ?? 0).compareTo(
          (a['reporting_year'] as int?) ?? 0,
        ),
      );
    final cards = recent.take(3).toList();
    if (cards.isEmpty) {
      return Panel(
        title: 'Recent outputs',
        child: const Text(
          'No outputs yet. Add one in Scientific Outputs, or import from ORCID.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Panel(
      title: 'Recent outputs',
      trailing: TextButton(
        onPressed: () => onNavigate('/app/outputs'),
        child: const Text('See all →'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget card(Map<String, dynamic> output) => _OutputCard(
            output: output,
            onTap: () => onNavigate('/outputs/${output['id']}'),
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final output in cards) card(output)],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: card(cards[i])),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({required this.output, required this.onTap});

  final Map<String, dynamic> output;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final codes = output['issue_codes'];
    final code = codes is List && codes.isNotEmpty
        ? codes.first.toString()
        : null;
    final type = rootOf(output) ?? output['type']?.toString() ?? 'Unclassified';
    final year = output['reporting_year']?.toString() ?? '—';
    return InkWell(
      onTap: onTap,
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$type · $year',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              output['title']?.toString() ?? 'Untitled output',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              code == null ? 'No issues' : issueLabel(code),
              style: TextStyle(
                color: code == null ? AppColors.textMuted : AppColors.amberDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
