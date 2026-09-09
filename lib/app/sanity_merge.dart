import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/merge_matrix.dart';
import '../widgets/panels.dart';
import '../widgets/search_bar.dart';

String _name(Map<String, dynamic> row) =>
    row['preferred_name'] as String? ?? 'Unnamed';

class SanityMergeScreen extends StatefulWidget {
  const SanityMergeScreen({super.key});

  @override
  State<SanityMergeScreen> createState() => _SanityMergeScreenState();
}

class _SanityMergeScreenState extends State<SanityMergeScreen> {
  late Future<List<Map<String, dynamic>>> _matches = fetchSanityMatches();
  late Future<List<Map<String, dynamic>>> _sanityOnly = _loadSanityOnly();
  late Future<List<Map<String, dynamic>>> _supabaseOnly =
      fetchPeopleWithoutSanity();
  String _query = '';
  bool? _listed;
  bool _statusMismatch = false;

  Future<List<Map<String, dynamic>>> _loadSanityOnly() =>
      fetchSanityMembers(query: _query, listed: _listed);

  void _refresh() => setState(() {
    _matches = fetchSanityMatches();
    _sanityOnly = _loadSanityOnly();
    _supabaseOnly = fetchPeopleWithoutSanity();
  });

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const ColoredBox(
            color: AppColors.cardBg,
            child: TabBar(
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.teal,
              tabs: [
                Tab(text: 'Matches'),
                Tab(text: 'Sanity only'),
                Tab(text: 'Supabase only'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [_matchesTab(), _sanityTab(), _supabaseTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchesTab() => AsyncView<List<Map<String, dynamic>>>(
    future: _matches,
    retry: () async => fetchSanityMatches(),
    builder: (context, rows) {
      final visible = rows.where((row) {
        if (!_statusMismatch) return true;
        final unlisted = row['sanity_unlisted'] == true;
        return (unlisted && row['status'] == 'active') ||
            (!unlisted && row['status'] != 'active');
      }).toList();
      final safe = rows.where((row) {
        final conflicts = row['conflicts'] as Map?;
        return row['match_kind'] != 'name' &&
            row['ambiguous'] != true &&
            !(conflicts?.containsKey('email') ?? false);
      }).length;
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: safe == 0 ? null : () => _bulkLink(safe),
                  icon: const Icon(Icons.link),
                  label: Text('Link $safe safe matches'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Status mismatch'),
                  selected: _statusMismatch,
                  onSelected: (selected) =>
                      setState(() => _statusMismatch = selected),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No matches')),
              )
            else
              for (final row in visible) _matchPanel(row),
          ],
        ),
      );
    },
  );

  Widget _matchPanel(Map<String, dynamic> match) {
    final conflicts = (match['conflicts'] as Map?)?.keys.length ?? 0;
    final subtitle = [
      match['match_kind'],
      if (match['ambiguous'] == true) 'AMBIGUOUS',
      '$conflicts conflict${conflicts == 1 ? '' : 's'}',
      match['preferred_name'],
    ].whereType<String>().join(' · ');
    final sanity = {
      'id': match['sanity_id'],
      'preferred_name': match['sanity_name'],
      'email': match['sanity_email'],
      'orcid': match['sanity_orcid'],
      'ciencia_id': match['sanity_ciencia_id'],
      'bio': match['sanity_bio'],
      'photo_url': match['sanity_photo_url'],
      'status': match['sanity_unlisted'] == true ? 'inactive' : 'active',
      'membership_type': null,
    };
    final mismatch =
        (match['sanity_unlisted'] == true && match['status'] == 'active') ||
        (match['sanity_unlisted'] != true && match['status'] != 'active');
    return Panel(
      title: match['sanity_name'] as String? ?? 'Unnamed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted)),
          if (mismatch)
            Text(
              match['sanity_unlisted'] == true
                  ? 'not listed on site / active here'
                  : 'listed on site / not active here',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                final person = await fetchPerson(match['person_id'] as String);
                if (mounted) {
                  _openMatrix(person, sanity, match['sanity_id'] as String);
                }
              },
              child: const Text('Review & link'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkLink(int safe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          'Sets the Sanity link on $safe people. No person field is changed; '
          'ORCID, bio, photo and name-form values from Sanity go to Suggestions for review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await bulkLinkSanityMatches();
      if (!mounted) return;
      showSnack(
        context,
        'Linked ${result['linked']} · ${result['suggestions']} suggestions filed · ${result['skipped']} skipped',
      );
      _refresh();
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  Widget _sanityTab() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        SearchBarField(
          label: 'Search Sanity members',
          onChanged: (q) => setState(() {
            _query = q;
            _sanityOnly = _loadSanityOnly();
          }),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Listed'),
                selected: _listed == true,
                onSelected: (v) => _setListed(v ? true : null),
              ),
              FilterChip(
                label: const Text('Unlisted'),
                selected: _listed == false,
                onSelected: (v) => _setListed(v ? false : null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AsyncView<List<Map<String, dynamic>>>(
            future: _sanityOnly,
            builder: (context, rows) => rows.isEmpty
                ? const Center(child: Text('No Sanity-only members'))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _sanityTile(rows[i]),
                  ),
          ),
        ),
      ],
    ),
  );

  void _setListed(bool? value) => setState(() {
    _listed = value;
    _sanityOnly = _loadSanityOnly();
  });

  Widget _sanityTile(Map<String, dynamic> row) {
    final details = [
      row['sanity_member_type_ref'] as String?,
      if ((row['email'] as String?)?.isNotEmpty == true) 'email',
      if ((row['photo_url'] as String?)?.isNotEmpty == true) 'photo',
      if ((row['bio'] as String?)?.isNotEmpty == true) 'bio',
    ].whereType<String>().join(' · ');
    return Panel(
      title: _name(row),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _import(row),
                child: const Text('Import'),
              ),
              OutlinedButton(
                onPressed: () => _ignore(row),
                child: const Text('Ignore'),
              ),
              TextButton(
                onPressed: () => _choosePerson(row),
                child: const Text('Link…'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _import(Map<String, dynamic> row) async {
    try {
      await importSanityMember(row['sanity_id'] as String);
      if (!mounted) return;
      showSnack(context, 'Imported as draft');
      _refresh();
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  Future<void> _ignore(Map<String, dynamic> row) async {
    try {
      await setSanityDecision(row['sanity_id'] as String, 'ignored');
      if (!mounted) return;
      showSnack(context, 'Ignored');
      _refresh();
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  Future<void> _choosePerson(Map<String, dynamic> sanity) async {
    final people = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _PersonPicker(),
    );
    if (people == null || people.isEmpty || !mounted) return;
    _openMatrix(people.first, sanity, sanity['sanity_id'] as String);
  }

  Future<void> _openMatrix(
    Map<String, dynamic> person,
    Map<String, dynamic> sanity,
    String sanityId,
  ) async {
    final linked = await showDialog<bool>(
      context: context,
      builder: (context) => MergeMatrixDialog(
        title: 'Link to Sanity',
        records: [person, sanity],
        fields: personMergeFields,
        nameOf: _name,
        onMerge: (survivorId, loserIds, fields) async {
          if (survivorId != person['id']) {
            showSnack(context, 'Supabase person must be the survivor');
            return;
          }
          await linkSanityMember(person['id'] as String, sanityId, fields);
        },
      ),
    );
    if (linked == true && mounted) _refresh();
  }

  Widget _supabaseTab() => AsyncView<List<Map<String, dynamic>>>(
    future: _supabaseOnly,
    retry: () async => fetchPeopleWithoutSanity(),
    builder: (context, rows) => ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, i) => Panel(
        child: ListTile(
          title: Text(_name(rows[i])),
          subtitle: Text(
            [
              rows[i]['status'],
              rows[i]['membership_type'],
            ].whereType<String>().join(' · '),
          ),
        ),
      ),
    ),
  );
}

class _PersonPicker extends StatefulWidget {
  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Link to existing person'),
    content: SizedBox(
      width: 500,
      height: 500,
      child: Column(
        children: [
          SearchBarField(
            label: 'Search people',
            onChanged: (q) => setState(() => _people = fetchPeople(query: q)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncView<List<Map<String, dynamic>>>(
              future: _people,
              builder: (context, people) => ListView(
                children: [
                  for (final person in people)
                    ListTile(
                      title: Text(_name(person)),
                      subtitle: Text(person['email'] as String? ?? ''),
                      onTap: () => Navigator.of(context).pop([person]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );
}
