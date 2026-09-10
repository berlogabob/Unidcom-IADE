import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/attention.dart';
import '../data/features.dart';
import '../data/output_filters.dart';
import '../data/supabase.dart';
import '../public/person/featured_outputs.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/output_row.dart';
import '../widgets/panels.dart';
import '../widgets/status_strip.dart';
import 'my_profile.dart' show profileStatusLabel;

/// Home-page fetch, public so the split-out `/app/home/*` leaves (see
/// portal_pages.dart) can each load it independently instead of the researcher
/// home composing them from one already-loaded value.
typedef HomeData = ({
  Map<String, dynamic>? person,
  List<Map<String, dynamic>> outputs,
  List<Map<String, dynamic>> requests,
  List<Map<String, dynamic>> candidates,
  List<Map<String, dynamic>> suggestions,
});

Future<HomeData> loadHomeData() async {
  final mine = await fetchMyPerson();
  if (mine == null) {
    return (
      person: null,
      outputs: const <Map<String, dynamic>>[],
      requests: const <Map<String, dynamic>>[],
      candidates: const <Map<String, dynamic>>[],
      suggestions: const <Map<String, dynamic>>[],
    );
  }

  final results = await Future.wait<Object>([
    fetchPerson(mine['id'] as String),
    fetchMyRequests(),
    fetchMyCandidates(mine['id'] as String),
    fetchMySuggestions(mine['id'] as String),
  ]);
  final person = results[0] as Map<String, dynamic>;
  final outputs =
      [
        for (final author
            in person['output_authors'] as List<dynamic>? ?? const [])
          if (author is Map && author['outputs'] is Map)
            Map<String, dynamic>.from(author['outputs'] as Map),
      ]..sort(
        (a, b) => ((b['reporting_year'] as int?) ?? 0).compareTo(
          (a['reporting_year'] as int?) ?? 0,
        ),
      );
  await mergeOutputQuality(outputs);
  return (
    person: person,
    outputs: outputs,
    requests: results[1] as List<Map<String, dynamic>>,
    candidates: results[2] as List<Map<String, dynamic>>,
    suggestions: results[3] as List<Map<String, dynamic>>,
  );
}

class ResearcherHomePage extends StatefulWidget {
  const ResearcherHomePage({super.key});

  @override
  State<ResearcherHomePage> createState() => _ResearcherHomePageState();
}

class _ResearcherHomePageState extends State<ResearcherHomePage> {
  late final Future<HomeData> _data = loadHomeData();

  @override
  Widget build(BuildContext context) {
    // No signed-out branch: /app/home is auth-gated in main.dart, so an
    // anonymous visitor never reaches this widget.
    return AsyncView<HomeData>(
      future: _data,
      retry: loadHomeData,
      builder: (context, data) {
        final person = data.person;
        if (person == null) return const _NoProfileView();

        return ColoredBox(
          color: AppColors.pageBg,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _IdentityHeader(
                    person: person,
                    pendingCandidates: data.candidates
                        .where(
                          (candidate) =>
                              candidate['status'] == 'pending' &&
                              candidate['matched_output_id'] == null,
                        )
                        .length,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final left = Column(
                        children: [
                          OverviewAlerts(
                            person: person,
                            requests: data.requests,
                            outputs: data.outputs,
                            candidates: data.candidates,
                            suggestions: data.suggestions,
                          ),
                          const SizedBox(height: 16),
                          RecentOutputs(outputs: data.outputs),
                        ],
                      );
                      final right = Column(
                        children: [
                          OutputSummary(
                            outputs: data.outputs,
                            featured: featuredOf(person).length,
                          ),
                          const SizedBox(height: 16),
                          _SyncLine(
                            person: person,
                            pending: pendingProposals(data.suggestions),
                          ),
                          if (v2) ...[
                            const SizedBox(height: 16),
                            const QuickLinks(),
                          ],
                        ],
                      );
                      if (constraints.maxWidth < 760) {
                        return Column(
                          children: [left, const SizedBox(height: 16), right],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 16),
                          Expanded(child: right),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.person,
    required this.pendingCandidates,
  });

  final Map<String, dynamic> person;
  final int pendingCandidates;

  @override
  Widget build(BuildContext context) {
    final name = person['preferred_name'] as String? ?? 'Researcher';
    final photo = (person['photo_url'] as String? ?? '').trim();
    final job = (person['job_title'] as String? ?? '').trim();
    final membership = membershipLabels[person['membership_type']] ?? '';
    final role = job.isNotEmpty
        ? job
        : membership.isNotEmpty
        ? membership
        : 'Researcher';
    final orcid = (person['orcid'] as String? ?? '').trim();
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
            child: photo.isEmpty ? Text(initials) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text('$role · UNIDCOM / IADE'),
                if (orcid.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('ORCID iD $orcid', style: const TextStyle(fontSize: 12)),
                ],
                const SizedBox(height: 12),
                StatusStrip(
                  person: person,
                  pendingCandidates: pendingCandidates,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OutputSummary extends StatelessWidget {
  const OutputSummary({
    super.key,
    required this.outputs,
    required this.featured,
  });

  final List<Map<String, dynamic>> outputs;
  final int featured;

  @override
  Widget build(BuildContext context) {
    final counts = countByType(outputs);
    final classified = counts.entries
        .where((entry) => entry.key != 'Unclassified')
        .toList();
    final unclassified = counts['Unclassified'];
    final entries = [
      ...classified.take(unclassified == null ? 6 : 5),
      if (unclassified != null)
        MapEntry<String, int>('Unclassified', unclassified),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeader(context, 'Scientific Outputs · ${outputs.length}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              InkWell(
                onTap: () => context.go('/app/outputs'),
                child: SizedBox(
                  width: 150,
                  child: AccentStatCard(
                    label: entry.key,
                    value: '${entry.value}',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => context.go('/app/outputs'),
          child: AccentStatCard(
            label: 'FEATURED OUTPUTS',
            value: '$featured / $maxFeaturedOutputs',
          ),
        ),
      ],
    );
  }
}

class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.person, required this.pending});

  final Map<String, dynamic> person;
  final int pending;

  @override
  Widget build(BuildContext context) {
    String date(Object? value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      return parsed == null ? 'never' : _shortDate(parsed);
    }

    return mutedText(
      context,
      [
        'ORCID last checked ${date(person['orcid_synced_at'])}',
        'Profile updated ${date(person['updated_at'])}',
        if (pending > 0)
          '$pending ${pending == 1 ? 'change' : 'changes'} awaiting UNIDCOM review',
      ].join(' · '),
    );
  }
}

class _NoProfileView extends StatelessWidget {
  const _NoProfileView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No researcher profile is linked to your account.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/app/profile'),
                  child: const Text('Open profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Outputs / active-requests / profile-status cards. Public: also the body
/// of the `/app/home/summary` leaf (see portal_pages.dart).
class OverviewStats extends StatelessWidget {
  const OverviewStats({super.key, required this.person, required this.data});

  final Map<String, dynamic> person;
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final active = data.requests
        .where(
          (request) => const {'draft', 'submitted'}.contains(request['status']),
        )
        .length;
    final status = person['profile_status'] as String? ?? 'not confirmed';
    final verified = person['last_verified_at']?.toString();
    final cards = [
      AccentStatCard(label: 'OUTPUTS', value: '${data.outputs.length}'),
      if (v2)
        AccentStatCard(
          label: 'ACTIVE REQUESTS',
          value: '$active',
          tone: active > 0 ? AccentTone.warn : AccentTone.neutral,
        ),
      AccentStatCard(
        label: 'PROFILE STATUS',
        value: profileStatusLabel(status),
        tone: status == 'approved' ? AccentTone.good : AccentTone.warn,
      ),
      // M2 — Rui, 14 Aug: "Last verified → hide"
      if (v2)
        AccentStatCard(
          label: 'LAST VERIFIED',
          value: verified == null || verified.isEmpty
              ? 'Never'
              : verified.split('T').first,
          tone: AccentTone.info,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Researcher action list. Public: also the body of the
/// `/app/home/alerts` leaf (see portal_pages.dart).
class OverviewAlerts extends StatelessWidget {
  const OverviewAlerts({
    super.key,
    required this.person,
    required this.requests,
    this.outputs = const [],
    this.candidates = const [],
    this.suggestions = const [],
    this.now,
  });

  final Map<String, dynamic> person;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> outputs;
  final List<Map<String, dynamic>> candidates;
  final List<Map<String, dynamic>> suggestions;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final alerts = attentionItems(
      person: person,
      outputs: outputs,
      candidates: candidates,
      suggestions: suggestions,
    );

    return Panel(
      title: 'Needs Your Attention',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (alerts.isEmpty)
            Material(
              color: AppColors.tealTint,
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.tealDark,
                ),
                title: Text(
                  'No action required · Last checked ${_shortDate(now ?? DateTime.now())}',
                  style: const TextStyle(color: AppColors.tealDark),
                ),
              ),
            )
          else
            for (var i = 0; i < alerts.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              // One Material per row so ListTile's tint is visible.
              Material(
                color: AppColors.amberTintSoft,
                child: ListTile(
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.amberDark,
                    size: 20,
                  ),
                  title: Text(
                    alerts[i].text,
                    style: const TextStyle(color: AppColors.amberDark),
                  ),
                  trailing: const Text(
                    '→',
                    style: TextStyle(color: AppColors.amberDark),
                  ),
                  onTap: () => context.go(alerts[i].route),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class RecentOutputs extends StatefulWidget {
  const RecentOutputs({super.key, required this.outputs});
  final List<Map<String, dynamic>> outputs;
  @override
  State<RecentOutputs> createState() => _RecentOutputsState();
}

class _RecentOutputsState extends State<RecentOutputs> {
  // ponytail: expands to all, no paging — a researcher has tens of outputs, not thousands.
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final outputs = widget.outputs;
    final shown = _expanded ? outputs : outputs.take(3).toList();
    return Panel(
      title: 'Recent Outputs',
      trailing: outputs.length <= 3 || _expanded
          ? null
          : TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: const Text('More'),
            ),
      padding: EdgeInsets.zero,
      child: outputs.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No outputs yet.'),
            )
          : Column(
              children: [
                for (final output in shown)
                  OutputRow(
                    title: output['title'] as String? ?? 'Untitled output',
                    year: output['reporting_year'] as int?,
                    type: output['type'] as String?,
                    onTap: () => context.go('/outputs/${output['id']}'),
                  ),
              ],
            ),
    );
  }
}

/// Quick links to the Welcome-pack resources. Public: also the body of the
/// `/app/help/links` leaf (see portal_pages.dart).
class QuickLinks extends StatelessWidget {
  const QuickLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final links = [
      (label: 'UNIDCOM affiliation text', route: '/app/welcome/affiliation'),
      // M2 — Rui, 14 Aug: "open access M2".
      if (v2) (label: 'Open Access', route: '/app/welcome/oa'),
      (label: 'Download logos', route: '/app/welcome/logos'),
      (label: 'Email signature', route: '/app/welcome/signature'),
    ];
    return Panel(
      title: 'Quick links',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              title: Text(links[i].label),
              trailing: const Text('→'),
              onTap: () => context.go(links[i].route),
            ),
          ],
        ],
      ),
    );
  }
}
