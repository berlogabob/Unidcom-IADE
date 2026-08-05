import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/output_row.dart';
import '../widgets/panels.dart';

typedef _HomeData = ({
  Map<String, dynamic>? person,
  List<Map<String, dynamic>> outputs,
  List<Map<String, dynamic>> requests,
});

class ResearcherHomePage extends StatefulWidget {
  const ResearcherHomePage({super.key});

  @override
  State<ResearcherHomePage> createState() => _ResearcherHomePageState();
}

class _ResearcherHomePageState extends State<ResearcherHomePage> {
  late final Future<_HomeData> _data = _load();

  Future<_HomeData> _load() async {
    final mine = await fetchMyPerson();
    if (mine == null) {
      return (
        person: null,
        outputs: const <Map<String, dynamic>>[],
        requests: const <Map<String, dynamic>>[],
      );
    }

    final results = await Future.wait<Object>([
      fetchPerson(mine['id'] as String),
      fetchMyRequests(),
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
    return (
      person: person,
      outputs: outputs,
      requests: results[1] as List<Map<String, dynamic>>,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentSession == null) {
      return const _SignedOutView();
    }

    return AsyncView<_HomeData>(
      future: _data,
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
                  _Stats(person: person, data: data),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final left = Column(
                        children: [
                          _Alerts(person: person, requests: data.requests),
                          const SizedBox(height: 16),
                          _RecentOutputs(outputs: data.outputs),
                        ],
                      );
                      final right = Column(
                        children: [
                          _SupportRequests(requests: data.requests),
                          const SizedBox(height: 16),
                          const _QuickLinks(),
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

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sign in to view your researcher home'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _Stats extends StatelessWidget {
  const _Stats({required this.person, required this.data});

  final Map<String, dynamic> person;
  final _HomeData data;

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
      AccentStatCard(
        label: 'ACTIVE REQUESTS',
        value: '$active',
        tone: active > 0 ? AccentTone.warn : AccentTone.neutral,
      ),
      AccentStatCard(
        label: 'PROFILE STATUS',
        value: status.replaceAll('_', ' '),
        tone: status == 'approved' ? AccentTone.good : AccentTone.warn,
      ),
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

class _Alerts extends StatelessWidget {
  const _Alerts({required this.person, required this.requests});

  final Map<String, dynamic> person;
  final List<Map<String, dynamic>> requests;

  @override
  Widget build(BuildContext context) {
    final alerts =
        <
          ({
            Color background,
            Color foreground,
            IconData icon,
            String text,
            String? route,
          })
        >[];
    if (person['profile_status'] != 'approved') {
      alerts.add((
        background: AppColors.amberTintSoft,
        foreground: AppColors.amberDark,
        icon: Icons.warning_amber_rounded,
        text: 'Your profile is awaiting confirmation',
        route: '/app/profile',
      ));
    }
    if (requests.any((request) => request['status'] == 'rejected')) {
      alerts.add((
        background: AppColors.redTint,
        foreground: AppColors.red,
        icon: Icons.error_outline,
        text: 'A support request was rejected',
        route: '/app/requests',
      ));
    }
    if (alerts.isEmpty) {
      alerts.add((
        background: AppColors.tealTint,
        foreground: AppColors.tealDark,
        icon: Icons.check_circle_outline,
        text: 'All good',
        route: null,
      ));
    }

    return Panel(
      title: 'Alerts',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              tileColor: alerts[i].background,
              leading: Icon(
                alerts[i].icon,
                color: alerts[i].foreground,
                size: 20,
              ),
              title: Text(
                alerts[i].text,
                style: TextStyle(color: alerts[i].foreground),
              ),
              trailing: alerts[i].route == null
                  ? null
                  : Text('→', style: TextStyle(color: alerts[i].foreground)),
              onTap: alerts[i].route == null
                  ? null
                  : () => context.go(alerts[i].route!),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentOutputs extends StatelessWidget {
  const _RecentOutputs({required this.outputs});

  final List<Map<String, dynamic>> outputs;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Recent outputs',
      trailing: TextButton(
        onPressed: () => context.go('/app/profile'),
        child: const Text('See all →'),
      ),
      padding: EdgeInsets.zero,
      child: outputs.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No outputs yet.'),
            )
          : Column(
              children: [
                for (final output in outputs.take(3))
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

class _SupportRequests extends StatelessWidget {
  const _SupportRequests({required this.requests});

  final List<Map<String, dynamic>> requests;

  PillTone _tone(String status) => switch (status) {
    'submitted' => PillTone.amber,
    'approved' => PillTone.teal,
    'rejected' => PillTone.red,
    'completed' => PillTone.blue,
    _ => PillTone.grey,
  };

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Support requests',
      trailing: TextButton(
        onPressed: () => context.go('/app/requests'),
        child: const Text('See all →'),
      ),
      padding: EdgeInsets.zero,
      child: requests.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No requests yet.'),
            )
          : Column(
              children: [
                for (var i = 0; i < requests.take(3).length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(
                      requests[i]['title'] as String? ?? 'Untitled request',
                    ),
                    subtitle: Text(requests[i]['type'] as String? ?? ''),
                    trailing: StatusPill(
                      (requests[i]['status'] as String? ?? 'draft').replaceAll(
                        '_',
                        ' ',
                      ),
                      tone: _tone(requests[i]['status'] as String? ?? 'draft'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    const links = [
      (label: 'UNIDCOM affiliation text', route: '/app/welcome/affiliation'),
      (label: 'Open Access', route: '/app/welcome/oa'),
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
