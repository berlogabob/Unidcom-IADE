import 'dart:convert';

import 'package:flutter/material.dart';

const websiteIssueKinds = ['differs', 'website_only', 'portal_only', 'same'];
const websiteIssueEntities = ['people', 'outputs'];
const websiteIssueLabels = {
  'differs': 'Differs',
  'website_only': 'Website only',
  'portal_only': 'Portal only',
  'same': 'Same',
};

typedef WebsiteIssue = Map<String, dynamic>;

/// Fixed group order for both the list and its CSV export.
Map<String, List<WebsiteIssue>> groupWebsiteIssues(
  List<WebsiteIssue> issues, {
  String? kind,
  String? entity,
}) => {
  for (final k in websiteIssueKinds)
    for (final e in websiteIssueEntities)
      if ((kind == null || kind == k) && (entity == null || entity == e))
        if (issues.any((i) => i['kind'] == k && i['entity'] == e))
          '$k/$e': [
            for (final i in issues)
              if (i['kind'] == k && i['entity'] == e) i,
          ],
};

String websiteIssueValue(dynamic value) => value == null
    ? '(missing)'
    : value is String
    ? value
    : jsonEncode(value);

String websiteIssuesCsv(List<WebsiteIssue> issues) {
  // Protect spreadsheet users from formula execution, including pasted values.
  String cell(dynamic value) {
    var text = value == null ? '' : websiteIssueValue(value);
    if (RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = <List<dynamic>>[
    ['kind', 'entity', 'key', 'label', 'field', 'portal', 'website', 'note'],
    for (final group in groupWebsiteIssues(issues).values)
      for (final issue in group)
        for (final field
            in (issue['fields'] as List).isEmpty
                ? [<String, dynamic>{}]
                : issue['fields'] as List)
          [
            issue['kind'],
            issue['entity'],
            issue['key'],
            issue['label'],
            field['name'],
            field['portal'],
            field['website'],
            issue['note'],
          ],
  ];
  return rows.map((row) => row.map(cell).join(',')).join('\r\n');
}

/// Session-independent list: counts always describe the full comparison.
class WebsiteDifferencesView extends StatefulWidget {
  const WebsiteDifferencesView({
    super.key,
    required this.issues,
    required this.onCopy,
  });

  final List<WebsiteIssue> issues;
  final Future<void> Function(String csv) onCopy;

  @override
  State<WebsiteDifferencesView> createState() => _WebsiteDifferencesViewState();
}

class _WebsiteDifferencesViewState extends State<WebsiteDifferencesView> {
  String? _kind;
  String? _entity;

  @override
  Widget build(BuildContext context) {
    final groups = groupWebsiteIssues(
      widget.issues,
      kind: _kind,
      entity: _entity,
    );
    final visible = groups.values.expand((g) => g).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final kind in websiteIssueKinds)
              FilterChip(
                label: Text(
                  '${websiteIssueLabels[kind]} (${widget.issues.where((i) => i['kind'] == kind).length})',
                ),
                selected: _kind == kind,
                onSelected: (on) => setState(() => _kind = on ? kind : null),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final entity in websiteIssueEntities)
              FilterChip(
                label: Text(
                  '$entity (${widget.issues.where((i) => i['entity'] == entity).length})',
                ),
                selected: _entity == entity,
                onSelected: (on) =>
                    setState(() => _entity = on ? entity : null),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: Text('Copy as CSV (${visible.length})'),
            onPressed: visible.isEmpty
                ? null
                : () => widget.onCopy(websiteIssuesCsv(visible)),
          ),
        ),
        if (groups.isEmpty) const Text('No records for these filters.'),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${websiteIssueLabels[entry.value.first['kind']]} · ${entry.value.first['entity']} (${entry.value.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final issue in entry.value)
            ExpansionTile(
              title: Text('${issue['label']}'),
              subtitle: Text('${issue['key']}'),
              children: [
                if (issue['note'] != null)
                  ListTile(title: Text('${issue['note']}')),
                if ((issue['fields'] as List).isEmpty)
                  const ListTile(
                    title: Text('All compared fields are the same.'),
                  ),
                for (final field in issue['fields'] as List)
                  ListTile(
                    title: Text('${field['name']}'),
                    subtitle: SelectableText(
                      'Portal: ${websiteIssueValue(field['portal'])}\nWebsite: ${websiteIssueValue(field['website'])}',
                    ),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}
