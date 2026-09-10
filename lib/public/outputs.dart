import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../data/status_labels.dart';
import '../data/taxonomy.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/output_row.dart';
import '../widgets/panels.dart';
import '../widgets/queue_list.dart';
import '../widgets/search_bar.dart';
import '../widgets/taxonomy_picker.dart';
import 'output_page.dart';

class OutputsScreen extends StatefulWidget {
  const OutputsScreen({super.key});

  @override
  State<OutputsScreen> createState() => _OutputsScreenState();
}

class _OutputsScreenState extends State<OutputsScreen> {
  String _query = '';
  String _year = '';
  List<String> _category = const [];
  String? _approvalStatus;
  String? _severity; // null = All · 'Any issue' · 'Errors' · 'Warnings'
  late Future<List<Map<String, dynamic>>> _outputs = fetchOutputs();
  late final Future<List<TaxonomyNode>> _taxonomy = fetchOutputTaxonomy();

  void _load() {
    final year = int.tryParse(_year);
    setState(
      () => _outputs = fetchOutputs(
        query: _query,
        year: year,
        categoryPath: _category,
        approvalStatus: _approvalStatus,
      ),
    );
  }

  void _search(String value) {
    _query = value;
    _load();
  }

  /// Admins insert directly — they hold `outputs_write`. Same dialog the
  /// researcher gets, so the taxonomy cascade is the only way in for both.
  Future<void> _addOutput() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const OutputEditDialog(),
    );
    if (saved ?? false) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: SearchBarField(onChanged: _search)),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: SearchBarField(
                  label: 'Year',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _year = value;
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<TaxonomyNode>>(
            future: _taxonomy,
            builder: (context, snapshot) => _filters(snapshot.data ?? const []),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncView<List<Map<String, dynamic>>>(
              future: _outputs,
              builder: (context, allOutputs) {
                final outputs = _severity == null
                    ? allOutputs
                    : allOutputs.where((o) {
                        final errors = o['error_count'] as int? ?? 0;
                        final warnings = o['warning_count'] as int? ?? 0;
                        switch (_severity) {
                          case 'Errors':
                            return errors > 0;
                          case 'Warnings':
                            return errors == 0 && warnings > 0;
                          default: // 'Any issue'
                            return errors > 0 || warnings > 0;
                        }
                      }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${outputs.length} outputs',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: outputs.isEmpty
                          ? const Center(child: Text('No outputs found'))
                          : ListView(
                              children: [
                                Panel(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < outputs.length;
                                        index++
                                      ) ...[
                                        if (outputs[index]['reporting_year'] !=
                                                null &&
                                            (index == 0 ||
                                                outputs[index -
                                                        1]['reporting_year'] !=
                                                    outputs[index]['reporting_year']))
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              14,
                                              16,
                                              8,
                                            ),
                                            child: Text(
                                              '${outputs[index]['reporting_year']}',
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        _outputRow(outputs[index]),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
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

  /// The Type row used to be a flat wrap of thirteen pills, several of them
  /// 70 characters of Portuguese, which is what prompted "use the same three
  /// comboboxes as filter". Quartile went with it: Q1–Q4 are already nodes
  /// under `Artigos em revistas`, so the cascade asks that question in its own
  /// place instead of as a second control that silently means nothing for the
  /// other ten categories.
  Widget _filters(List<TaxonomyNode> taxonomy) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TaxonomyPicker(
          roots: taxonomy,
          value: _category,
          onChanged: (value) {
            _category = value;
            _load();
          },
        ),
        // Admin only: every row in the corpus is currently `approved`, so to a
        // researcher this is a control whose every setting but one returns an
        // empty list. It earns its place on the review side, not here.
        if (isAdmin)
          filterDropdown(
            'Approval',
            _approvalStatus,
            const ['pending', 'approved', 'rejected'],
            (value) {
              _approvalStatus = value;
              _load();
            },
          ),
        if (isAdmin)
          filterDropdown('Issues', _severity, const [
            'Any issue',
            'Errors',
            'Warnings',
          ], (value) => setState(() => _severity = value)),
        TextButton.icon(
          onPressed: () => context.go('/conferences'),
          icon: const Icon(Icons.event),
          label: const Text('Conferences'),
        ),
        if (isAdmin)
          FilledButton.icon(
            onPressed: _addOutput,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add output'),
          ),
      ],
    );
  }

  Widget _outputRow(Map<String, dynamic> output) {
    final authors = (output['output_authors'] as List<dynamic>? ?? [])
        .map((author) {
          final people = (author as Map<String, dynamic>)['people'];
          return (people as Map<String, dynamic>?)?['preferred_name']
              as String?;
        })
        .whereType<String>()
        .join(', ');
    return OutputRow(
      title: output['title'] as String? ?? 'Untitled',
      year: output['reporting_year'] as int?,
      type: output['type'] as String?,
      detail: authors,
      issueCodes: isAdmin
          ? (output['issue_codes'] as List<dynamic>? ?? []).cast<String>()
          : null,
      errorCount: output['error_count'] as int? ?? 0,
      warningCount: output['warning_count'] as int? ?? 0,
      extraPills: isAdmin
          ? [
              (
                'Website · ${websiteLabel(output['website_status'] as String?)}',
                output['website_status'] == 'published'
                    ? PillTone.teal
                    : PillTone.grey,
              ),
            ]
          : const [],
      onTap: () => context.go('/outputs/${output['id']}'),
    );
  }
}
