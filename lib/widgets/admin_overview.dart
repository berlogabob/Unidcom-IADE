import 'package:flutter/material.dart';

import 'package:unidcom_iade/data/admin_stats.dart';
import 'package:unidcom_iade/theme/tokens.dart';
import 'package:unidcom_iade/widgets/info_tip.dart';
import 'package:unidcom_iade/widgets/panels.dart';
import 'package:unidcom_iade/widgets/ds_page.dart';

/// Rui 25 Sep (Admin B1): the admin dashboard, numbers only.
class AdminOverview extends StatelessWidget {
  const AdminOverview({
    super.key,
    required this.stats,
    required this.years,
    this.year,
    required this.onYear,
    required this.activity,
    this.alerts = const [],
    required this.onOpenPerson,
    required this.onOpenProfilesToApprove,
    required this.onOpenOutputsToApprove,
    this.proposalsToReview = 0,
    this.onOpenProposals,
  });

  final AdminStats stats;
  final List<int> years;
  final int? year;
  final ValueChanged<int?> onYear;
  final ({int lastMonth, int lastWeek, int never}) activity;
  final List<({String text, String personId})> alerts;
  final ValueChanged<String> onOpenPerson;
  final VoidCallback onOpenProfilesToApprove;
  final VoidCallback onOpenOutputsToApprove;
  final int proposalsToReview;
  final VoidCallback? onOpenProposals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: dsGap,
          runSpacing: dsGap,
          children: [
            _tile(context, 'Integrated researchers', stats.integrated),
            _tile(context, 'Collaborators', stats.collaborators),
            _tile(
              context,
              'Profiles to approve',
              stats.profilesToApprove,
              onTap: onOpenProfilesToApprove,
            ),
            _tile(
              context,
              'Outputs to approve',
              stats.outputsToApprove,
              onTap: onOpenOutputsToApprove,
            ),
            _tile(
              context,
              'Proposals to review',
              proposalsToReview,
              onTap: onOpenProposals,
              info:
                  'Changes researchers proposed to their profile or outputs '
                  '(for example a new bio from ORCID). Review them in '
                  'Pending approval → Suggestions.',
            ),
          ],
        ),
        const SizedBox(height: dsGap),
        Wrap(
          spacing: dsGap,
          runSpacing: dsGap,
          children: [
            _card(
              'Sync status',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(
                    'ORCID: ${stats.orcidLinked} linked · ${stats.orcidNotLinked} not linked',
                  ),
                  _line(
                    'Website: ${stats.sitePublished} published · '
                    '${stats.siteApprovedNotPublished} approved, not published · '
                    '${stats.siteNotPublished} not published',
                  ),
                ],
              ),
            ),
            _card(
              'Researcher activity',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'low priority',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  _line('Logged in last month · ${activity.lastMonth}'),
                  _line('Active last week · ${activity.lastWeek}'),
                  _line('Never logged in · ${activity.never}'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: dsGap),
        Wrap(
          spacing: dsGap,
          runSpacing: dsGap,
          children: [
            _card(
              'Issues',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line('Missing DOI · ${stats.missingDoi}'),
                  _line('Not on ORCID · ${stats.notOnOrcid}'),
                ],
              ),
            ),
            _card(
              'Outputs by type',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: year == null,
                        selectedColor: AppColors.navy,
                        backgroundColor: AppColors.cardBg,
                        labelStyle: TextStyle(
                          color: year == null
                              ? AppColors.cardBg
                              : AppColors.textPrimary,
                        ),
                        onSelected: (_) => onYear(null),
                      ),
                      ...years.map(
                        (value) => ChoiceChip(
                          label: Text('$value'),
                          selected: year == value,
                          selectedColor: AppColors.navy,
                          backgroundColor: AppColors.cardBg,
                          labelStyle: TextStyle(
                            color: year == value
                                ? AppColors.cardBg
                                : AppColors.textPrimary,
                          ),
                          onSelected: (_) => onYear(value),
                        ),
                      ),
                    ],
                  ),
                  _line('Total · ${stats.outputsTotal}'),
                  ...stats.outputsByType.entries.map(
                    (entry) => _line('${entry.key} · ${entry.value}'),
                  ),
                ],
              ),
            ),
            _card(
              'Critical alerts',
              alerts.isEmpty
                  ? const Text(
                      'No critical alerts',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  : Column(
                      children: alerts
                          .map(
                            (alert) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.warn,
                              ),
                              title: Text(alert.text),
                              onTap: () => onOpenPerson(alert.personId),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    String label,
    int value, {
    VoidCallback? onTap,
    String? info,
  }) {
    final child = Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
          ),
          info == null
              ? Text(
                  label,
                  style: const TextStyle(color: AppColors.textSecondary),
                )
              : WithInfo(
                  info: info,
                  child: Text(
                    label,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
        ],
      ),
    );
    return SizedBox(
      width: 200,
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }

  Widget _card(String title, Widget child) {
    return SizedBox(
      width: 360,
      child: Panel(title: title, child: child),
    );
  }

  Text _line(String text) =>
      Text(text, style: const TextStyle(color: AppColors.textSecondary));
}
