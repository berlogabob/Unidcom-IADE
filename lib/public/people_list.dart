import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/features.dart';
import '../data/supabase.dart';
import '../theme/tokens.dart';
import 'person_page.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/ds_page.dart';
import '../widgets/panels.dart';
import '../widgets/queue_list.dart';
import '../widgets/search_bar.dart';

class PeopleListScreen extends StatefulWidget {
  const PeopleListScreen({super.key});

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
  String _query = '';
  String? _membershipType;
  String? _status;
  String? _profileStatus;
  bool _missingOrcid = false;
  bool _needsVerification = false;
  bool _hasOutputs = false;
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();

  void _search(String value) {
    _query = value;
    _load();
  }

  void _load() {
    setState(
      () => _people = fetchPeople(
        query: _query,
        membershipType: _membershipType,
        status: _status,
        profileStatus: _profileStatus,
        missingOrcid: _missingOrcid,
        needsVerification: _needsVerification,
        hasOutputs: _hasOutputs,
      ),
    );
  }

  void _refresh() {
    _load();
  }

  Future<void> _addPerson() async {
    final saved = await showPersonEditor(context);
    if (saved) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: !v2 && isAdmin
          ? const EdgeInsets.fromLTRB(24, 16, 24, 16)
          : const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!v2 && isAdmin) ...[
            const DsTitleCard(
              title: 'People',
              subtitle:
                  'Every researcher, their review state and whether their profile is on the website.',
            ),
            const SizedBox(height: dsGap),
          ],
          Row(
            children: [
              Expanded(child: SearchBarField(onChanged: _search)),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addPerson,
                  icon: const Icon(Icons.add),
                  label: const Text('Add person'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncView<List<Map<String, dynamic>>>(
              future: _people,
              builder: (context, people) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${people.length} people',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: people.isEmpty
                          ? const Center(child: Text('No people found'))
                          : Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: const BoxDecoration(
                                color: AppColors.cardBg,
                                border: Border.fromBorderSide(
                                  BorderSide(color: AppColors.cardBorder),
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(AppDims.radius),
                                ),
                                boxShadow: AppDims.shadowCard,
                              ),
                              child: ListView.builder(
                                itemCount: people.length,
                                itemBuilder: (context, index) {
                                  final person = people[index];
                                  final membershipType =
                                      person['membership_type'] as String?;
                                  final status = person['status'] as String?;
                                  final email = person['email'] as String?;
                                  return Material(
                                    color: AppColors.cardBg,
                                    child: InkWell(
                                      onTap: () =>
                                          context.go('/people/${person['id']}'),
                                      hoverColor: AppColors.sandHover,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 13,
                                        ),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: AppColors.cardBorder,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    person['preferred_name']
                                                            as String? ??
                                                        'Unnamed',
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textPrimary,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (email != null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      email,
                                                      style: const TextStyle(
                                                        color:
                                                            AppColors.textMuted,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Flexible + Wrap: on a phone the badges
                                            // wrap instead of squeezing the name to one
                                            // letter per line (seen 30 Sep at 390 px).
                                            Flexible(
                                              child: Wrap(
                                                alignment: WrapAlignment.end,
                                                spacing: 8,
                                                runSpacing: 4,
                                                children: [
                                                  if (membershipType != null)
                                                    TypeBadge(membershipType),
                                                  if (status != null)
                                                    StatusPill(
                                                      queueStatusLabel(status),
                                                      tone: switch (status) {
                                                        'active' =>
                                                          PillTone.teal,
                                                        'a_confirmar' =>
                                                          PillTone.amber,
                                                        _ => PillTone.grey,
                                                      },
                                                    ),
                                                  StatusPill(
                                                    person['public_visibility'] ==
                                                            true
                                                        ? 'Website · Published'
                                                        : 'Website · Not published',
                                                    tone:
                                                        person['public_visibility'] ==
                                                            true
                                                        ? PillTone.teal
                                                        : PillTone.grey,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        filterDropdown(
          'Membership',
          _membershipType,
          membershipTypes, // Layer-1 values (integrated/collaborator/external)
          (value) {
            _membershipType = value;
            _load();
          },
        ),
        filterDropdown(
          'Status',
          _status,
          const ['a_confirmar', 'active', 'inactive'],
          (value) {
            _status = value;
            _load();
          },
        ),
        filterDropdown(
          'Profile',
          _profileStatus,
          const [
            'to_validate',
            'draft',
            'pending_review',
            'under_review',
            'approved',
          ],
          (value) {
            _profileStatus = value;
            _load();
          },
        ),
        FilterPill(
          'Missing ORCID',
          selected: _missingOrcid,
          onTap: () {
            _missingOrcid = !_missingOrcid;
            _load();
          },
        ),
        FilterPill(
          'Needs verification',
          selected: _needsVerification,
          onTap: () {
            _needsVerification = !_needsVerification;
            _load();
          },
        ),
        FilterPill(
          'Has outputs',
          selected: _hasOutputs,
          onTap: () {
            _hasOutputs = !_hasOutputs;
            _load();
          },
        ),
      ],
    );
  }
}
