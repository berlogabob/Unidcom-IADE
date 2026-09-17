import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../public/person_page.dart';
import '../widgets/portal_shell.dart';
import 'my_profile.dart';
import 'researcher_home.dart';

/// Tabs /people/:id/:tab can show; the first is what /people/:id opens.
const researcherTabs = {
  'overview': 'Overview',
  'profile': 'My Profile',
  'outputs': 'Scientific Outputs',
  'import': 'Import & Sync',
  'edit': 'Edit (admin)',
};

/// An admin's view of one researcher: their portal exactly as they see it,
/// plus the full admin detail page as the Edit tab.
class ResearcherView extends StatelessWidget {
  const ResearcherView({super.key, required this.id, this.tab = 'overview'});

  final String id;
  final String tab;

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      personId: id,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final entry in researcherTabs.entries)
                  ButtonSegment(value: entry.key, label: Text(entry.value)),
              ],
              selected: {tab},
              onSelectionChanged: (selected) =>
                  context.go('/people/$id/${selected.first}'),
            ),
          ),
          Expanded(
            child: switch (tab) {
              'profile' => MyProfileScreen(personId: id),
              'outputs' => MyProfileScreen(
                personId: id,
                section: MySection.outputs,
              ),
              'import' => MyProfileScreen(
                personId: id,
                section: MySection.importSync,
              ),
              'edit' => PersonPageScreen(id: id),
              _ => ResearcherHomePage(personId: id),
            },
          ),
        ],
      ),
    );
  }
}
