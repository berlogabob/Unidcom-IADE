import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/enrich_client.dart';
import '../data/features.dart';
import '../data/supabase.dart';
import '../public/person/orcid_sync_dialog.dart';
import '../public/output_page.dart';
import '../public/person_page.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

String profileStatusLabel(String? status) => switch (status) {
  'pending_review' => 'Awaiting UNIDCOM approval',
  'approved' => 'Approved',
  _ => 'Profile not confirmed',
};

String candidateSubtitle(Map<String, dynamic> row) => [
  row['reporting_year'],
  row['type'],
].where((value) => value != null && '$value'.isNotEmpty).join(' · ');

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();
  Map<String, dynamic>? _person;
  List<Map<String, dynamic>> _candidates = [];
  bool _resolved = false;
  bool _submitting = false;
  bool _addingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      // Self-heals when an admin fills people.orcid after first ORCID login.
      await claimPersonByOrcid();
      final person = await fetchMyPerson();
      final candidates = person == null
          ? <Map<String, dynamic>>[]
          : await fetchMyCandidates(person['id'] as String);
      if (!mounted) return;
      setState(() {
        _person = person;
        _candidates = candidates;
        _resolved = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _refresh() => _resolve();

  Future<void> _checkOrcidSync(String personId) async {
    try {
      final status = await fetchOrcidSyncStatus(personId);
      if (!mounted) return;
      if (status == null) {
        showSnack(context, 'No ORCID on this profile to check');
        return;
      }
      await showOrcidSyncDialog(context, status);
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  Future<void> _submitProfile() async {
    final person = _person;
    if (person == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await submitMyProfileForReview(person['id'] as String);
      if (!mounted) return;
      setState(() {
        _person = {...person, 'profile_status': 'pending_review'};
      });
      showSnack(context, 'Profile submitted for approval');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reviewCandidate(String id, {required bool promote}) async {
    try {
      if (promote) {
        await promoteCandidate(id);
      } else {
        await rejectCandidate(id);
      }
      if (!mounted) return;
      setState(() => _candidates.removeWhere((row) => row['id'] == id));
      showSnack(
        context,
        promote ? 'Publication added' : 'Publication marked as not mine',
      );
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  /// Files an output the researcher types in themselves. Saves through
  /// `create_my_output`, which stamps it pending and links them as an author —
  /// they have no write grant on `outputs` and are not getting one.
  Future<void> _addOutput() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const OutputEditDialog(asResearcher: true),
    );
    if (saved ?? false) _refresh();
  }

  /// Rui: "dont do it as toggle - just show and add a sync botton to all - so
  /// that i dont have to do it for each one." Eight publications meant eight
  /// clicks; this is the one.
  ///
  /// ponytail: sequential, not Future.wait — promoteCandidate writes an output
  /// plus an author link per call, and a researcher has single digits of these.
  /// Parallelise if anyone ever arrives with hundreds.
  Future<void> _addAllCandidates() async {
    if (_addingAll || _candidates.isEmpty) return;
    setState(() => _addingAll = true);
    final ids = [for (final row in _candidates) row['id'] as String];
    var added = 0;
    try {
      for (final id in ids) {
        await promoteCandidate(id);
        added++;
      }
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) {
        // Drop what actually landed, not the whole list: a failure halfway
        // through must not hide the ones still waiting.
        setState(() {
          _candidates.removeWhere((row) => ids.take(added).contains(row['id']));
          _addingAll = false;
        });
        if (added > 0) {
          showSnack(context, '$added publication${added == 1 ? '' : 's'} added');
        }
      }
    }
  }

  /// Adds ORCID as a login method for the signed-in account; if the person
  /// registry lists this iD, the profile is claimed server-side too.
  Future<void> _connectOrcid() async {
    try {
      final returnTo = kIsWeb
          ? '${Uri.base.origin}${Uri.base.path}'
          : 'https://berlogabob.github.io/Unidcom-IADE/';
      final url = await startOrcidLink(returnTo);
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  Future<void> _link(Map<String, dynamic> person) async {
    final name = person['preferred_name'] as String? ?? 'this profile';
    // ponytail: one-tap claim caused accidental mis-links ("checking" someone
    // else's account bound it to you). A confirm dialog is the whole fix.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link this profile to YOUR login?'),
        content: Text(
          'Your account will show "$name" as your own profile. '
          'Only do this to claim your OWN researcher profile — '
          'not to view or check someone else\'s account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Link to me'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await linkPersonToMe(person['id'] as String);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile linked')));
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped by AppShell (Scaffold + app bar + bottom nav) — no Scaffold here.
    if (_error != null) return Center(child: Text(_error!));
    if (!_resolved) return const Center(child: CircularProgressIndicator());

    final person = _person;
    if (person != null) {
      final status = person['profile_status'] as String? ?? 'draft';
      // ponytail: still the detail page, now with two slots. Split only if the
      // own-profile UI genuinely diverges from the directory one.
      return PersonPageScreen(
        // Re-key on claims too, so a promoted publication shows up below.
        key: ValueKey('$status-${_candidates.length}'),
        id: person['id'] as String,
        leading: [
          // Row, not a Wrap with a Spacer in it: Spacer is an Expanded, which
          // asserts outside a Flex, and inside a Wrap it silently takes the
          // button down with it.
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                      profileStatusLabel(status),
                      tone: status == 'approved'
                          ? PillTone.teal
                          : PillTone.amber,
                    ),
                    if (status == 'draft') ...[
                      const Text('Check your data below, then confirm'),
                      FilledButton(
                        onPressed: _submitting ? null : _submitProfile,
                        child: const Text('Confirm my profile'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // The "+add" half of "this works for both filtering my outputs
              // as well as when i click +add" — same cascade, same dialog.
              FilledButton.icon(
                onPressed: _addOutput,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add output'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // v2: the old banner's "Sync now" opens a diff dialog and imports
          // nothing — one of the three things Rui named as noise. What he
          // asked for instead is the single Add all button at the bottom.
          if (v2 && (person['orcid'] as String? ?? '').isNotEmpty) ...[
            _syncBanner(context, person),
            const SizedBox(height: 16),
          ],
        ],
        trailing: [const SizedBox(height: 24), _orcidCandidates(context)],
      );
    }

    return _unlinkedView();
  }

  /// Always on screen and never a toggle — "dont do it as toggle - just show".
  /// Sits last, below the outputs, because that is where it was asked to go.
  Widget _orcidCandidates(BuildContext context) {
    return Panel(
      title: 'My ORCID publications · ${_candidates.length}',
      trailing: _candidates.isEmpty
          ? null
          : FilledButton.icon(
              onPressed: _addingAll ? null : _addAllCandidates,
              icon: _addingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.library_add_outlined, size: 18),
              label: Text(_addingAll ? 'Adding...' : 'Add all'),
            ),
      padding: EdgeInsets.zero,
      child: _candidates.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nothing new from ORCID. Publications you add there show up '
                'here for you to confirm.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (final candidate in _candidates)
                  ListTile(
                    title: Text(candidate['title'] as String? ?? 'Untitled'),
                    subtitle: Text(candidateSubtitle(candidate)),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _addingAll
                              ? null
                              : () => _reviewCandidate(
                                  candidate['id'] as String,
                                  promote: false,
                                ),
                          child: const Text('Not mine'),
                        ),
                        FilledButton(
                          onPressed: _addingAll
                              ? null
                              : () => _reviewCandidate(
                                  candidate['id'] as String,
                                  promote: true,
                                ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _syncBanner(BuildContext context, Map<String, dynamic> person) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.sync, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ORCID connected — outputs sync automatically',
              style: TextStyle(color: AppColors.tealDark, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => _checkOrcidSync(person['id'] as String),
            child: const Text('Sync now'),
          ),
        ],
      ),
    );
  }

  Widget _unlinkedView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            title: Text('No researcher profile is linked to your account.'),
          ),
        ),
        if (!hasLinkedOrcid) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _connectOrcid,
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Connect ORCID'),
            ),
          ),
        ],
        if (isAdmin) ...[
          const SizedBox(height: 16),
          Panel(
            title: 'Link a profile',
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search people',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _people = fetchPeople(query: value));
                  },
                ),
                const SizedBox(height: 12),
                AsyncView<List<Map<String, dynamic>>>(
                  future: _people,
                  builder: (context, people) {
                    return Column(
                      children: [
                        for (final person in people.take(20))
                          ListTile(
                            title: Text(
                              person['preferred_name'] as String? ?? 'Unnamed',
                            ),
                            subtitle: Text(person['email'] as String? ?? ''),
                            trailing: const Icon(Icons.link),
                            onTap: () => _link(person),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
