import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/orcid_update.dart';
import '../data/enrich_client.dart';
import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/suggestion_tile.dart';
import 'person/featured_outputs.dart';
import 'person/orcid_sync_dialog.dart';
import 'person/output_row.dart';
import 'person/person_dialogs.dart';
import 'person/profile_sections.dart';
import 'person/timeline.dart';

export 'person/featured_outputs.dart'
    show
        featuredOf,
        maxFeaturedOutputs,
        nextFeatured,
        orderByFeatured,
        outputIdOf;
export 'person/person_dialogs.dart' show showPersonEditor;

/// Rows with no affiliation recorded are UNIDCOM's — that's the column default,
/// so every pre-import output lands here.
bool _isUnidcom(Map<String, dynamic> author) {
  final output = author['outputs'] as Map<String, dynamic>?;
  return (output?['affiliation'] as String? ?? 'unidcom') == 'unidcom';
}

class PersonPageScreen extends StatefulWidget {
  const PersonPageScreen({super.key, required this.id});

  final String id;

  @override
  State<PersonPageScreen> createState() => _PersonPageScreenState();
}

class _PersonPageScreenState extends State<PersonPageScreen> {
  late Future<Map<String, dynamic>> _person = fetchPerson(widget.id);
  late Future<List<Map<String, dynamic>>> _suggestions =
      fetchSuggestionsForPerson(widget.id);
  late Future<List<Map<String, dynamic>>> _roles = fetchPersonRoles(widget.id);
  bool _enriching = false;
  bool _syncing = false;

  void _refresh() {
    setState(() {
      _person = fetchPerson(widget.id);
      _suggestions = fetchSuggestionsForPerson(widget.id);
      _roles = fetchPersonRoles(widget.id);
    });
  }

  Future<void> _acceptSuggestion(String id) async {
    try {
      await acceptSuggestion(id);
      _refresh();
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _rejectSuggestion(String id) async {
    await rejectSuggestion(id);
    _refresh();
  }

  Future<void> _approve() async {
    await approvePerson(widget.id);
    if (!mounted) return;
    _refresh();
    _snack('Profile approved');
  }

  Future<void> _edit(
    Map<String, dynamic> person, {
    required bool canEditGovernance,
  }) async {
    final saved = await showPersonEditor(
      context,
      person: person,
      canEditGovernance: canEditGovernance,
    );
    if (saved == true) _refresh();
  }

  Future<void> _autoFill(Map<String, dynamic> person) async {
    setState(() => _enriching = true);
    try {
      final incoming = await fetchOrcidValues(widget.id);
      if (!mounted) return;
      if (incoming == null) {
        _snack('No ORCID profile found to pull from');
        return;
      }
      final applied = await showOrcidUpdateDialog(
        context,
        personId: widget.id,
        current: person,
        incoming: incoming,
      );
      if (applied && mounted) _refresh();
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Future<void> _checkOrcidSync() async {
    setState(() => _syncing = true);
    try {
      final status = await fetchOrcidSyncStatus(widget.id);
      if (!mounted) return;
      if (status == null) {
        _snack('No ORCID on this profile to check');
        return;
      }
      await showOrcidSyncDialog(context, status);
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _snack("Couldn't open link");
  }

  /// Adds ORCID as a login method for the signed-in account (broker link flow).
  Future<void> _connectOrcid() async {
    try {
      final returnTo = kIsWeb
          ? '${Uri.base.origin}${Uri.base.path}'
          : 'https://berlogabob.github.io/Unidcom-IADE/';
      final url = await startOrcidLink(returnTo);
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } catch (error) {
      _snack(error.toString());
    }
  }

  Widget _suggestionsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _suggestions,
      builder: (context, snapshot) {
        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('Suggestions', style: Theme.of(context).textTheme.titleLarge),
            for (final suggestion in suggestions)
              SuggestionTile(
                suggestion: suggestion,
                showTitle: false,
                onAccept: () => _acceptSuggestion(suggestion['id'] as String),
                onReject: () => _rejectSuggestion(suggestion['id'] as String),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addRole() async {
    final added = await showPersonRoleDialog(context, widget.id);
    if (added == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<Map<String, dynamic>>(
      future: _person,
      retry: () => fetchPerson(widget.id),
      builder: (context, person) {
        final admin = isAdmin;
        final isOwner =
            person['auth_user_id'] != null &&
            person['auth_user_id'] == db.auth.currentUser?.id;
        final outputAuthors = (person['output_authors'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final featured = featuredOf(person);
        // Work from a prior affiliation stays on the profile but out of the
        // UNIDCOM list — and out of every count, which the DB enforces.
        final ordered = orderByFeatured(
          outputAuthors.where(_isUnidcom).toList(),
          featured,
        );
        final external = outputAuthors.where((a) => !_isUnidcom(a)).toList();
        final labMemberships = (person['lab_members'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .where((membership) => membership['labs'] is Map)
            .toList();

        return DetailBody(
          children: [
            personHeader(
              context,
              person,
              admin: admin,
              isOwner: isOwner,
              hasLinkedOrcid: hasLinkedOrcid,
              enriching: _enriching,
              syncing: _syncing,
              onEdit: () => _edit(person, canEditGovernance: admin),
              onConnectOrcid: _connectOrcid,
              onAutoFill: () => _autoFill(person),
              onCheckOrcidSync: _checkOrcidSync,
              onApprove: _approve,
            ),
            if (admin) _suggestionsSection(),
            ...personInfoSections(
              context,
              person,
              labMemberships,
              onOpen: _open,
              onOpenLab: (id) => context.go('/labs/$id'),
            ),
            () {
              final highlights = ordered
                  .where((author) => featured.contains(outputIdOf(author)))
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionHeader(context, 'Highlights · ${highlights.length}'),
                  const SizedBox(height: 8),
                  if (highlights.isEmpty)
                    mutedText(
                      context,
                      'No highlights yet — star outputs in the timeline below',
                    )
                  else
                    for (final author in highlights)
                      PersonOutputRow(
                        author: author,
                        isFeatured: true,
                        onToggle: admin || isOwner
                            ? (id) => _toggleFeatured(person, featured, id)
                            : null,
                        onTap: (id) => context.go('/outputs/$id'),
                      ),
                ],
              );
            }(),
            const SizedBox(height: 24),
            PersonTimelineSection(
              roles: _roles,
              authors: ordered,
              labMemberships: labMemberships,
              featured: featured,
              admin: admin,
              isOwner: isOwner,
              onToggleFeatured: (id) => _toggleFeatured(person, featured, id),
              onRefresh: _refresh,
              onAddRole: _addRole,
              onOpenOutput: (id) => context.go('/outputs/$id'),
              onOpenLab: (id) => context.go('/labs/$id'),
            ),
            if (external.isNotEmpty) ...[
              const SizedBox(height: 24),
              sectionHeader(context, 'Other affiliations · ${external.length}'),
              const SizedBox(height: 4),
              mutedText(
                context,
                'Published before or outside IADE/UNIDCOM. '
                'Not counted in unit reports.',
              ),
              const SizedBox(height: 8),
              for (final author in external)
                PersonOutputRow(
                  author: author,
                  isFeatured: false,
                  onTap: (id) => context.go('/outputs/$id'),
                ),
            ],
          ],
        );
      },
    );
  }

  /// Stars/unstars an output, keeping the array's order = display order.
  Future<void> _toggleFeatured(
    Map<String, dynamic> person,
    List<String> featured,
    String outputId,
  ) async {
    final next = nextFeatured(featured, outputId);
    if (identical(next, featured)) {
      _snack('Up to $maxFeaturedOutputs highlights');
      return;
    }
    try {
      await updatePerson(widget.id, {'featured_outputs': next});
      await logChanges('person', widget.id, person, {'featured_outputs': next});
      _refresh();
    } catch (error) {
      _snack(error.toString());
    }
  }

  void _snack(String message) {
    if (mounted) showSnack(context, message);
  }
}
