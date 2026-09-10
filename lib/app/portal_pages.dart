import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';
import 'my_profile.dart' show profileStatusLabel;
import 'researcher_home.dart';

/// The small standalone pages behind the IA leaves that are not big enough
/// (or not built yet) to earn their own file. One class per leaf, so the IA
/// trace matrix and this file line up one to one.

/// A leaf of the IA that has no content yet. One-to-one with the tree was the
/// ask; an honest placeholder beats a missing row.
class WipPage extends StatelessWidget {
  const WipPage({super.key, required this.title, this.note});

  final String title;
  final String? note;

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
                const Icon(
                  Icons.construction,
                  color: AppColors.textMuted,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Work in progress'),
                if (note != null) ...[
                  const SizedBox(height: 8),
                  mutedText(context, note!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

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
                const Icon(
                  Icons.search_off,
                  color: AppColors.textMuted,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  "We can't find that page.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small teal "not built yet" note dropped inline into a leaf that otherwise
/// has real content (see [OverviewSummaryPage]) — [WipPage] is for a leaf
/// that is nothing else, this is for one sentence inside one that isn't.
class WipCallout extends StatelessWidget {
  const WipCallout(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.construction, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.tealDark, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared frame for the small portal pages: sand background, 1100 max width,
/// 16 padding, a titleLarge heading.
class PortalPage extends StatelessWidget {
  const PortalPage({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _noProfilePanel() => const Panel(
  child: Text('No researcher profile is linked to your account.'),
);

/// `/app/home/summary` — the outputs/profile-status cards, plus a note that
/// the by-year/by-type/quality breakdown is not built yet.
class OverviewSummaryPage extends StatefulWidget {
  const OverviewSummaryPage({super.key});

  @override
  State<OverviewSummaryPage> createState() => _OverviewSummaryPageState();
}

class _OverviewSummaryPageState extends State<OverviewSummaryPage> {
  late final Future<HomeData> _data = loadHomeData();

  @override
  Widget build(BuildContext context) {
    return AsyncView<HomeData>(
      future: _data,
      retry: loadHomeData,
      builder: (context, data) {
        final person = data.person;
        return PortalPage(
          title: 'Research Activity Summary',
          child: person == null
              ? _noProfilePanel()
              : Column(
                  children: [
                    OverviewStats(person: person, data: data),
                    const SizedBox(height: 16),
                    const WipCallout(
                      'Outputs by year, by type and quality indicators — '
                      'work in progress',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// `/app/home/recent` — the Recent Outputs panel, standalone.
class OverviewRecentPage extends StatefulWidget {
  const OverviewRecentPage({super.key});

  @override
  State<OverviewRecentPage> createState() => _OverviewRecentPageState();
}

class _OverviewRecentPageState extends State<OverviewRecentPage> {
  late final Future<HomeData> _data = loadHomeData();

  @override
  Widget build(BuildContext context) {
    return AsyncView<HomeData>(
      future: _data,
      retry: loadHomeData,
      builder: (context, data) => PortalPage(
        title: 'Recent Scientific Outputs',
        child: RecentOutputs(outputs: data.outputs),
      ),
    );
  }
}

/// `/app/home/alerts` — the Alerts panel, standalone.
class OverviewAlertsPage extends StatefulWidget {
  const OverviewAlertsPage({super.key});

  @override
  State<OverviewAlertsPage> createState() => _OverviewAlertsPageState();
}

class _OverviewAlertsPageState extends State<OverviewAlertsPage> {
  late final Future<HomeData> _data = loadHomeData();

  @override
  Widget build(BuildContext context) {
    return AsyncView<HomeData>(
      future: _data,
      retry: loadHomeData,
      builder: (context, data) {
        final person = data.person;
        return PortalPage(
          title: 'Alerts & Notifications',
          child: person == null
              ? _noProfilePanel()
              : OverviewAlerts(person: person, requests: data.requests),
        );
      },
    );
  }
}

/// Status pill + "Confirm my profile", factored out of the leading slot in
/// my_profile.dart so a leaf can show the same thing on its own — reused by
/// `/app/home/status` here, and by `/app/profile/status` later.
class ProfileStatusPanel extends StatefulWidget {
  const ProfileStatusPanel({super.key, required this.person});

  final Map<String, dynamic> person;

  @override
  State<ProfileStatusPanel> createState() => _ProfileStatusPanelState();
}

class _ProfileStatusPanelState extends State<ProfileStatusPanel> {
  bool _submitting = false;
  Map<String, dynamic>? _override;

  Map<String, dynamic> get _person => _override ?? widget.person;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await submitMyProfileForReview(_person['id'] as String);
      if (!mounted) return;
      setState(() {
        _override = {..._person, 'profile_status': 'pending_review'};
      });
      showSnack(context, 'Profile submitted for approval');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _person['profile_status'] as String? ?? 'draft';
    return Panel(
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusPill(
            profileStatusLabel(status),
            tone: status == 'approved' ? PillTone.teal : PillTone.amber,
          ),
          if (status == 'draft')
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('Confirm my profile'),
            ),
        ],
      ),
    );
  }
}

/// `/app/home/status` — profile status, standalone.
class ProfileStatusPage extends StatefulWidget {
  const ProfileStatusPage({super.key});

  @override
  State<ProfileStatusPage> createState() => _ProfileStatusPageState();
}

class _ProfileStatusPageState extends State<ProfileStatusPage> {
  late final Future<Map<String, dynamic>?> _person = fetchMyPerson();

  @override
  Widget build(BuildContext context) {
    return AsyncView<Map<String, dynamic>?>(
      future: _person,
      retry: fetchMyPerson,
      builder: (context, person) => PortalPage(
        title: 'Profile Status',
        child: person == null
            ? _noProfilePanel()
            : ProfileStatusPanel(person: person),
      ),
    );
  }
}

/// `/app/help/links` — the Quick links panel, standalone.
class QuickLinksPage extends StatelessWidget {
  const QuickLinksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PortalPage(title: 'Quick Links', child: QuickLinks());
  }
}
