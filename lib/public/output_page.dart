import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/enrich_client.dart';
import '../data/supabase.dart';
import '../widgets/merge_matrix.dart';
import '../widgets/output_row.dart';
import '../widgets/person_card.dart';
import '../widgets/suggestion_tile.dart';

const _outputMergeFields = <MergeFieldSpec>[
  (key: 'title', label: 'Title', tall: true),
  (key: 'doi', label: 'DOI', tall: false),
  (key: 'url', label: 'URL', tall: false),
  (key: 'type', label: 'Type', tall: false),
  (key: 'subtype', label: 'Subtype', tall: false),
  (key: 'reporting_year', label: 'Reporting year', tall: false),
  (key: 'macro_type', label: 'Macro type', tall: false),
  (key: 'output_status', label: 'Output status', tall: false),
  (key: 'full_reference', label: 'Full reference', tall: true),
];

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
  bool _findingDoi = false;

  void _refresh() {
    setState(() {
      _output = fetchOutput(widget.id);
      _issues = fetchOutputIssues(widget.id);
      _suggestions = fetchSuggestionsForOutput(widget.id);
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    setState(() => _findingDoi = true);
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
    } finally {
      if (mounted) setState(() => _findingDoi = false);
    }
  }

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't open link")));
    }
  }

  Future<void> _edit(Map<String, dynamic> output) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _OutputEditDialog(output: output),
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No duplicates found')));
      return;
    }
    if (!mounted) return;
    final merged = await showDialog<bool>(
      context: context,
      builder: (context) => MergeMatrixDialog(
        title: 'Merge outputs',
        records: cluster,
        fields: _outputMergeFields,
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _output,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final output = snapshot.data ?? {};
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

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(context, output, admin),
                const SizedBox(height: 24),
                if (admin) _issuesSection(context, admin),
                if (admin) _suggestionsSection(context),
                _sectionTitle(context, 'Authors · ${authors.length}'),
                const SizedBox(height: 8),
                if (authors.isEmpty)
                  _muted(context, 'No authors listed')
                else
                  for (final author in authors) _authorCard(context, author),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Projects · ${projects.length}'),
                const SizedBox(height: 8),
                if (projects.isEmpty)
                  _muted(context, 'Not linked to a project')
                else
                  for (final link in projects) _projectTile(context, link),
              ],
            ),
          ),
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
    final category = (output['category_path'] as String? ?? '').trim();
    final reference = (output['full_reference'] as String? ?? '').trim();
    final doi = (output['doi'] as String? ?? '').trim();
    final doiStatus = output['doi_status'] as String?;
    final doiCheckedAt = (output['doi_checked_at'] as String? ?? '')
        .split('T')
        .first;
    final link = resolveOutputUrl(output['url'] as String?, doi);
    final chips = [
      output['reporting_year']?.toString(),
      output['macro_type'] as String?,
      output['type'] as String?,
      output['subtype'] as String?,
      output['output_status'] as String?,
      output['approval_status'] as String?,
    ].whereType<String>().where((v) => v.isNotEmpty);
    final fctSelected = output['fct_selected'] as bool? ?? false;
    final verified = output['verified_online'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              output['title'] as String? ?? 'Untitled',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final chip in chips)
                  Chip(label: Text(chip), visualDensity: VisualDensity.compact),
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
            ),
            if (reference.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                reference,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (doi.isNotEmpty) ...[
              const SizedBox(height: 8),
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
            if (category.isNotEmpty) ...[
              const SizedBox(height: 8),
              _muted(context, category),
            ],
            if (link != null || admin) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
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
                    OutlinedButton.icon(
                      onPressed: _findingDoi ? null : () => _findDoi(output),
                      icon: _findingDoi
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore, size: 18),
                      label: const Text('Find DOI'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _mergeDuplicates,
                      icon: const Icon(Icons.merge),
                      label: const Text('Merge duplicates'),
                    ),
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
              ),
            ],
          ],
        ),
      ),
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
            _sectionTitle(context, 'Suggestions · ${suggestions.length}'),
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
              _sectionTitle(context, 'Data quality · ${issues.length}'),
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

  Widget _projectTile(BuildContext context, Map<String, dynamic> link) {
    final project = link['projects'] as Map<String, dynamic>?;
    if (project == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        title: Text(project['title'] as String? ?? 'Untitled'),
        subtitle: Text(project['status'] as String? ?? ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/projects/${project['id']}'),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);

  Widget _muted(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
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

class _OutputEditDialog extends StatefulWidget {
  const _OutputEditDialog({required this.output});

  final Map<String, dynamic> output;

  @override
  State<_OutputEditDialog> createState() => _OutputEditDialogState();
}

class _OutputEditDialogState extends State<_OutputEditDialog> {
  late final _doi = _controller('doi');
  late final _fullReference = _controller('full_reference');
  late final _type = _controller('type');
  late final _subtype = _controller('subtype');
  late final _reportingYear = _controller('reporting_year');
  late final _outputStatus = _controller('output_status');
  late bool _verifiedOnline =
      widget.output['verified_online'] as bool? ?? false;
  bool _saving = false;

  TextEditingController _controller(String key) =>
      TextEditingController(text: widget.output[key]?.toString() ?? '');

  @override
  void dispose() {
    for (final c in [
      _doi,
      _fullReference,
      _type,
      _subtype,
      _reportingYear,
      _outputStatus,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final fields = {
        'doi': _text(_doi),
        'full_reference': _text(_fullReference),
        'type': _text(_type),
        'subtype': _text(_subtype),
        'reporting_year': _reportingYear.text.trim().isEmpty
            ? null
            : int.tryParse(_reportingYear.text.trim()),
        'output_status': _text(_outputStatus),
        'verified_online': _verifiedOnline,
      };
      await updateOutput(widget.output['id'] as String, fields);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit output'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_doi, 'DOI'),
              _field(_fullReference, 'Full reference', maxLines: 4),
              Row(
                children: [
                  Expanded(child: _field(_type, 'Type')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_subtype, 'Subtype')),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _reportingYear,
                      'Reporting year',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_outputStatus, 'Output status')),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Verified online'),
                value: _verifiedOnline,
                onChanged: (v) => setState(() => _verifiedOnline = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
