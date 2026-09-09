import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/enrich_client.dart';
import '../data/features.dart';
import '../data/supabase.dart';
import '../data/taxonomy.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/merge_matrix.dart';
import '../widgets/output_row.dart';
import '../widgets/person_card.dart';
import '../widgets/suggestion_tile.dart';
import '../widgets/taxonomy_picker.dart';

String _outputMergeName(Map<String, dynamic> output) =>
    output['title'] as String? ?? 'Untitled';

class OutputPageScreen extends StatefulWidget {
  const OutputPageScreen({super.key, required this.id});

  final String id;

  @override
  State<OutputPageScreen> createState() => _OutputPageScreenState();
}

class _OutputPageScreenState extends State<OutputPageScreen> {
  late Future<Map<String, dynamic>> _output = fetchOutput(widget.id);
  late Future<List<Map<String, dynamic>>> _issues = fetchOutputIssues(
    widget.id,
  );
  late Future<List<Map<String, dynamic>>> _suggestions =
      fetchSuggestionsForOutput(widget.id);

  void _refresh() {
    setState(() {
      _output = fetchOutput(widget.id);
      _issues = fetchOutputIssues(widget.id);
      _suggestions = fetchSuggestionsForOutput(widget.id);
    });
  }

  void _snack(String message) {
    if (mounted) showSnack(context, message);
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

  /// Searches Crossref by citation. Finding nothing is the normal outcome for
  /// outputs that genuinely have no DOI, so say so plainly rather than failing.
  Future<void> _findDoi(Map<String, dynamic> output) async {
    // No in-place spinner any more: this runs after the edit dialog has closed,
    // so there is no button left to disable. Progress is the snackbar.
    try {
      final match = await findDoiForOutput(widget.id);
      if (!mounted) return;
      if (match == null) {
        _snack('No confident Crossref match');
        return;
      }
      if (match['clashWith'] != null) {
        _snack(
          'That DOI already belongs to another output — possible duplicate. '
          'Use Merge duplicates.',
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use this DOI?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(match['doi'] as String),
              const SizedBox(height: 8),
              Text(match['title'] as String? ?? ''),
              const SizedBox(height: 8),
              Text(
                match['reason'] as String,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save DOI'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await updateOutput(widget.id, {'doi': match['doi']});
      await logChanges(
        'output',
        widget.id,
        output,
        {'doi': match['doi']},
        source: 'crossref',
      );
      _refresh();
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) showSnack(context, "Couldn't open link");
  }

  Future<void> _edit(Map<String, dynamic> output) async {
    // Ask before offering, so "Merge duplicates" is never a button whose only
    // possible outcome is a snackbar saying it had nothing to do. One small
    // query per Edit click is what "only if they exist" costs.
    var duplicates = 0;
    try {
      duplicates = (await fetchOutputCluster(widget.id)).length;
    } catch (_) {
      // Not worth blocking the editor over; the tool just is not offered.
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => OutputEditDialog(
        output: output,
        onFindDoi: v2 ? () => _findDoi(output) : null,
        onMerge: duplicates >= 2 ? _mergeDuplicates : null,
      ),
    );
    if (saved ?? false) _refresh();
  }

  Future<void> _waive(String issueCode) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _WaiveDialog(issueCode: issueCode),
    );
    if (reason == null) return;
    await waiveIssue(widget.id, issueCode, reason);
    if (mounted) _refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete output?'),
        content: const Text(
          'This permanently removes the output. Use this to resolve a genuine duplicate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await deleteOutput(widget.id);
    if (mounted) context.go('/outputs');
  }

  Future<void> _mergeDuplicates() async {
    final cluster = await fetchOutputCluster(widget.id);
    if (cluster.length < 2) {
      _snack('No duplicates found');
      return;
    }
    if (!mounted) return;
    final merged = await showDialog<bool>(
      context: context,
      builder: (context) => MergeMatrixDialog(
        title: 'Merge outputs',
        records: cluster,
        fields: outputMergeFields,
        nameOf: _outputMergeName,
        onMerge: mergeOutputs,
      ),
    );
    if (merged != true || !mounted) return;
    try {
      await fetchOutput(widget.id);
      if (mounted) _refresh();
    } catch (_) {
      // This output became a hidden loser (merged into another survivor).
      if (mounted) context.go('/outputs');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<Map<String, dynamic>>(
      future: _output,
      builder: (context, output) {
        final admin = isAdmin;
        final authors =
            (output['output_authors'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>()
                .toList()
              ..sort(
                (a, b) => (a['author_position'] as int? ?? 0).compareTo(
                  b['author_position'] as int? ?? 0,
                ),
              );
        final projects = (output['project_outputs'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        return DetailBody(
          children: [
            _header(context, output, admin),
            const SizedBox(height: 24),
            if (admin) _issuesSection(context, admin),
            if (admin) _suggestionsSection(context),
            sectionHeader(context, 'Authors · ${authors.length}'),
            const SizedBox(height: 8),
            if (authors.isEmpty)
              mutedText(context, 'No authors listed')
            else
              for (final author in authors) _authorCard(context, author),
            const SizedBox(height: 24),
            sectionHeader(context, 'Projects · ${projects.length}'),
            const SizedBox(height: 8),
            if (projects.isEmpty)
              mutedText(context, 'Not linked to a project')
            else
              for (final link in projects)
                if (link['projects'] is Map<String, dynamic>)
                  ProjectTile(
                    project: link['projects'] as Map<String, dynamic>,
                  ),
          ],
        );
      },
    );
  }

  Widget _header(
    BuildContext context,
    Map<String, dynamic> output,
    bool admin,
  ) {
    final theme = Theme.of(context);
    // Collapses the legacy four-column padding, so this reads correctly even
    // against data the repair migration has not reached (an old export, a
    // preview branch).
    final category = categorySegments(output['category_path'] as String?);
    final reference = (output['full_reference'] as String? ?? '').trim();
    final doi = (output['doi'] as String? ?? '').trim();
    final doiStatus = output['doi_status'] as String?;
    final doiCheckedAt = (output['doi_checked_at'] as String? ?? '')
        .split('T')
        .first;
    final link = resolveOutputUrl(output['url'] as String?, doi);
    // Rui: "separate that tree (type) from managing module (state and issues)".
    // macro_type / type / subtype are the first three columns of the same
    // padded path, so as chips they said the classification three more times —
    // often the same word twice. The breadcrumb below says it once; these are
    // only the things that describe the record's *state*.
    final chips = [
      output['reporting_year']?.toString(),
      output['output_status'] as String?,
      if (admin) output['approval_status'] as String?,
    ].whereType<String>().where((v) => v.isNotEmpty);
    final fctSelected = output['fct_selected'] as bool? ?? false;
    final verified = output['verified_online'] as bool? ?? false;

    return EntityHeaderCard(
      title: output['title'] as String? ?? 'Untitled',
      chips: [
        ...statusChips(chips),
        if (fctSelected)
          Chip(
            avatar: const Icon(Icons.flag, size: 16),
            label: const Text('FCT selected'),
            visualDensity: VisualDensity.compact,
            backgroundColor: theme.colorScheme.primaryContainer,
          ),
        if (verified)
          const Chip(
            avatar: Icon(Icons.verified, size: 16),
            label: Text('Verified online'),
            visualDensity: VisualDensity.compact,
          ),
      ],
      extra: [
        // The classification, said once, as the tree it actually is. What this
        // replaces rendered as "Organização de Seminários e Conferências ›
        // Organização de Seminários e Conferências › Membro da comissão
        // científica… › Membro da comissão científica…".
        if (category.isNotEmpty)
          Text(
            category.join('  ›  '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (reference.isNotEmpty)
          SelectableText(
            reference,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        if (doi.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText('DOI: $doi', style: theme.textTheme.bodySmall),
              if (doiStatus != null && doiStatus.isNotEmpty)
                Icon(
                  switch (doiStatus) {
                    'ok' => Icons.check_circle,
                    'dead' => Icons.error,
                    _ => Icons.help_outline,
                  },
                  size: 14,
                  color: switch (doiStatus) {
                    'ok' => Colors.green,
                    'dead' => theme.colorScheme.error,
                    _ => theme.colorScheme.onSurfaceVariant,
                  },
                ),
              if (doiStatus != null && doiStatus.isNotEmpty)
                Text(doiStatus, style: theme.textTheme.bodySmall),
              if (doiCheckedAt.isNotEmpty)
                Text(
                  '(checked $doiCheckedAt)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
      ],
      actions: [
        if (link != null)
          OutlinedButton.icon(
            onPressed: () => _open(context, link),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open paper'),
          ),
        if (admin) ...[
          FilledButton.icon(
            onPressed: () => _edit(output),
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
          // Find DOI and Merge duplicates used to sit here, in everyone's way.
          // They live inside the Edit dialog now — see _edit.
          PopupMenuButton<void>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _delete,
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _suggestionsSection(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _suggestions,
      builder: (context, snapshot) {
        final suggestions = snapshot.data ?? const [];
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(context, 'Suggestions · ${suggestions.length}'),
            const SizedBox(height: 8),
            for (final suggestion in suggestions)
              SuggestionTile(
                suggestion: suggestion,
                showTitle: false,
                onAccept: () => _acceptSuggestion(suggestion['id'] as String),
                onReject: () => _rejectSuggestion(suggestion['id'] as String),
                // A duplicate_of clash names another output, not a column
                // value — accepting it would write a field that doesn't exist.
                onOpenClash: suggestion['field'] == 'duplicate_of'
                    ? () => context.go(
                        '/outputs/${suggestion['suggested_value']}',
                      )
                    : null,
                clashTitle: suggestion['clash_title'] as String?,
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _issuesSection(BuildContext context, bool admin) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _issues,
      builder: (context, snapshot) {
        final issues = snapshot.data ?? [];
        if (issues.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader(context, 'Data quality · ${issues.length}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final issue in issues) _issueTile(context, issue, admin),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _issueTile(
    BuildContext context,
    Map<String, dynamic> issue,
    bool admin,
  ) {
    final theme = Theme.of(context);
    final code = issue['issue_code'] as String? ?? '';
    final severity = issue['severity'] as String? ?? 'warning';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          avatar: Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: severity == 'error' ? theme.colorScheme.error : Colors.amber,
          ),
          label: Text(code.replaceAll('_', ' ')),
          visualDensity: VisualDensity.compact,
        ),
        if (admin)
          TextButton(
            onPressed: () => _waive(code),
            child: const Text('Waive…'),
          ),
      ],
    );
  }

  Widget _authorCard(BuildContext context, Map<String, dynamic> author) {
    final person = author['people'] as Map<String, dynamic>?;
    if (person == null) return const SizedBox.shrink();
    final personId = person['id'] as String;
    return PersonCard(
      name: person['preferred_name'] as String? ?? 'Unnamed',
      membershipType: person['membership_type'] as String?,
      status: author['role'] as String? ?? person['status'] as String?,
      onTap: () => context.go('/people/$personId'),
    );
  }

}

class _WaiveDialog extends StatefulWidget {
  const _WaiveDialog({required this.issueCode});

  final String issueCode;

  @override
  State<_WaiveDialog> createState() => _WaiveDialogState();
}

class _WaiveDialogState extends State<_WaiveDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Waive "${widget.issueCode.replaceAll('_', ' ')}"'),
      content: TextField(
        controller: _reason,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Reason',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _reason.text.trim();
            Navigator.of(context).pop(reason.isEmpty ? null : reason);
          },
          child: const Text('Waive'),
        ),
      ],
    );
  }
}

/// Add or edit an output. `output == null` is the add case, following the same
/// `_creating` shape as `_PersonEditDialog` and `_ProjectEditDialog`.
///
/// One dialog for both because the taxonomy cascade has to appear in both —
/// "this works for both filtering my outputs as well as when i click +add".
class OutputEditDialog extends StatefulWidget {
  const OutputEditDialog({
    super.key,
    this.output,
    this.onFindDoi,
    this.onMerge,
    this.asResearcher = false,
    this.lookup = lookupDoi,
    this.findSimilar = findSimilarOutputs,
    this.create,
  });

  final Map<String, dynamic>? output;

  /// Rui: "find DOI and merge duplicates should only show after i click EDIT.
  /// And merge duplicates only if they exist." Null means don't offer it — the
  /// caller decides, because only it knows whether duplicates exist and whether
  /// this is a v2 build.
  final VoidCallback? onFindDoi;
  final VoidCallback? onMerge;

  /// Save through `create_my_output` instead of a direct insert. A researcher
  /// has no write grant on `outputs`; the RPC is their doorway, and it stamps
  /// the record pending for review.
  final bool asResearcher;
  final Future<DoiWork?> Function(String doi) lookup;
  final Future<List<Map<String, dynamic>>> Function({String? doi, String? title})
      findSimilar;
  final Future<String> Function(Map<String, dynamic> fields)? create;

  @override
  State<OutputEditDialog> createState() => _OutputEditDialogState();
}

class _OutputEditDialogState extends State<OutputEditDialog> {
  late final _title = _controller('title');
  late final _doi = _controller('doi');
  late final _fullReference = _controller('full_reference');
  late final _reportingYear = _controller('reporting_year');
  late final _outputStatus = _controller('output_status');
  late List<String> _category = categorySegments(
    widget.output?['category_path'] as String?,
  );
  late bool _verifiedOnline =
      widget.output?['verified_online'] as bool? ?? false;
  late final Future<List<TaxonomyNode>> _taxonomy = fetchOutputTaxonomy();
  bool _saving = false;
  String? _titleError;
  final _titleFocus = FocusNode();
  bool _lookingUp = false;
  String? _lookupMessage;
  Map<String, dynamic>? _doiMatch;
  List<Map<String, dynamic>> _titleMatches = [];
  String? _checkedDoi;
  String? _checkedTitle;

  bool get _creating => widget.output?['id'] == null;

  TextEditingController _controller(String key) =>
      TextEditingController(text: widget.output?[key]?.toString() ?? '');

  @override
  void dispose() {
    _titleFocus.dispose();
    for (final c in [
      _title,
      _doi,
      _fullReference,
      _reportingYear,
      _outputStatus,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Pops first, then runs. Stacking a merge matrix on top of an open editor
  /// leaves two modals and an unsaved form behind whichever one you dismiss.
  void _runTool(VoidCallback tool) {
    Navigator.of(context).pop(false);
    tool();
  }

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _lookup() async {
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
      _doiMatch = null;
      _titleMatches = [];
    });
    try {
      final work = await widget.lookup(_doi.text);
      if (!mounted) return;
      if (work == null) {
        setState(() => _lookupMessage =
            'No record found for that DOI — fill in the details below.');
        return;
      }
      setState(() {
        _title.text = work.title;
        _titleError = null;
        _doi.text = work.doi;
        if (work.year != null) _reportingYear.text = '${work.year}';
        _fullReference.text = [
          work.authors.join(', '),
          work.containerTitle,
          if (work.year != null) '${work.year}',
        ].where((part) => part.isNotEmpty).join(' · ');
        switch (work.type) {
          case 'journal-article':
            _category = ['Artigos em revistas'];
          case 'book':
          case 'book-chapter':
            _category = ['Livros'];
        }
      });
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _openMatch(Map<String, dynamic> match) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop(false);
    router.go('/outputs/${match['id']}');
  }

  Future<void> _save({bool saveAnyway = false}) async {
    if (_saving || _lookingUp) return;

    // title is the one NOT NULL column, and the RPC raises on a blank one.
    // Catching it here means a typo costs a glance, not a round trip.
    if (_text(_title) == null) {
      setState(() => _titleError = 'A title is required');
      return;
    }
    setState(() {
      _titleError = null;
      _saving = true;
    });
    try {
      if (_creating) {
        final doi = cleanDoi(_doi.text);
        final title = _text(_title);
        final confirmed = saveAnyway && _titleMatches.isNotEmpty &&
            doi == _checkedDoi && title == _checkedTitle;
        if (!confirmed) {
          final matches = await widget.findSimilar(doi: doi, title: title);
          if (!mounted) return;
          final doiMatch = matches.where((row) => row['match'] == 'doi').firstOrNull;
          final titleMatches = matches.where((row) =>
              row['match'] == 'title' && (row['score'] as num? ?? 0) >= 0.8)
              .take(3).toList();
          setState(() {
            _checkedDoi = doi;
            _checkedTitle = title;
            _doiMatch = doiMatch;
            _titleMatches = doiMatch == null ? titleMatches : [];
          });
          if (doiMatch != null || titleMatches.isNotEmpty) {
            setState(() => _saving = false);
            return;
          }
        }
      }
      final fields = {
        'title': _text(_title),
        'doi': _text(_doi),
        'full_reference': _text(_fullReference),
        'category_path': _category.isEmpty
            ? null
            : _category.join(categorySeparator),
        // report_data() builds the annual PDF's sections from macro_type and
        // its subsections from subtype, so the path alone would drop this
        // output out of the report. Free-text Type/Subtype boxes are how the
        // vocabulary drifted in the first place; the cascade writes all three.
        ...categoryFields(_category),
        'reporting_year': _reportingYear.text.trim().isEmpty
            ? null
            : int.tryParse(_reportingYear.text.trim()),
        'output_status': _text(_outputStatus),
        if (!widget.asResearcher) 'verified_online': _verifiedOnline,
      };
      if (!_creating) {
        await updateOutput(widget.output!['id'] as String, fields);
      } else if (widget.asResearcher) {
        // Forces pending/manual/unidcom server-side and links the author.
        await (widget.create ?? createMyOutput)(fields);
      } else {
        await (widget.create ?? createOutput)(fields);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showSnack(context, error.toString());
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_creating ? 'Add output' : 'Edit output'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_creating) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _doi,
                        enabled: !_lookingUp && !_saving,
                        decoration: const InputDecoration(
                          labelText: 'DOI (or paste the doi.org link)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {
                          _doiMatch = null;
                          _titleMatches = [];
                          _lookupMessage = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _lookingUp || _saving ? null : _lookup,
                      child: Text(_lookingUp ? 'Looking up…' : 'Look up'),
                    ),
                  ],
                ),
                if (_lookupMessage != null) Text(_lookupMessage!),
                if (_doiMatch != null) ...[
                  Text('Already in the directory: ${_doiMatch!['title']} '
                      '(${_doiMatch!['approval_status']})'),
                  TextButton(
                    onPressed: () => _openMatch(_doiMatch!),
                    child: const Text('Open'),
                  ),
                ],
                TextButton(
                  onPressed: () => _titleFocus.requestFocus(),
                  child: const Text('No DOI? Enter the details manually'),
                ),
                const SizedBox(height: 12),
              ],
              // Was missing entirely — the dialog only ever edited existing
              // rows, so nothing had to supply the one required column.
              TextField(
                controller: _title,
                focusNode: _titleFocus,
                enabled: !_saving && !_lookingUp,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: const OutlineInputBorder(),
                  errorText: _titleError,
                ),
                maxLines: 2,
                minLines: 1,
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
              ),
              const SizedBox(height: 12),
              if (!_creating) editField(_doi, 'DOI'),
              editField(_fullReference, 'Full reference', maxLines: 4),
              const SizedBox(height: 4),
              FutureBuilder<List<TaxonomyNode>>(
                future: _taxonomy,
                builder: (context, snapshot) => TaxonomyPicker(
                  roots: snapshot.data ?? const [],
                  value: _category,
                  onChanged: (value) => setState(() => _category = value),
                  width: 508,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: editField(
                      _reportingYear,
                      'Reporting year',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: editField(_outputStatus, 'Output status')),
                ],
              ),
              // Curation state, not something a researcher asserts about
              // their own work — and the RPC would ignore it anyway.
              if (!widget.asResearcher)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verified online'),
                  value: _verifiedOnline,
                  onChanged: (v) => setState(() => _verifiedOnline = v),
                ),
              if (widget.asResearcher && _creating) ...[
                const SizedBox(height: 12),
                Text(
                  'UNIDCOM reviews what you add before it appears on the '
                  'public site.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (_titleMatches.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final match in _titleMatches) ...[
                          Text('Looks like ${match['title']} '
                              '(${match['reporting_year'] ?? 'Unknown year'})'),
                          TextButton(
                            onPressed: _saving ? null : () => _openMatch(match),
                            child: const Text("It's the same — open it"),
                          ),
                        ],
                        TextButton(
                          onPressed: _saving ? null : () => _save(saveAnyway: true),
                          child: const Text("It's different — save anyway"),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.onFindDoi != null || widget.onMerge != null) ...[
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.onFindDoi != null)
                        OutlinedButton.icon(
                          onPressed: () => _runTool(widget.onFindDoi!),
                          icon: const Icon(Icons.travel_explore, size: 18),
                          label: const Text('Find DOI'),
                        ),
                      if (widget.onMerge != null)
                        OutlinedButton.icon(
                          onPressed: () => _runTool(widget.onMerge!),
                          icon: const Icon(Icons.merge, size: 18),
                          label: const Text('Merge duplicates'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: editorActions(context, saving: _saving || _lookingUp, onSave: _save),
    );
  }
}
