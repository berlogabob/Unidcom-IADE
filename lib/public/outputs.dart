import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/output_row.dart';
import '../widgets/panels.dart';
import '../widgets/search_bar.dart';

class OutputsScreen extends StatefulWidget {
  const OutputsScreen({super.key});

  @override
  State<OutputsScreen> createState() => _OutputsScreenState();
}

class _OutputsScreenState extends State<OutputsScreen> {
  String _query = '';
  String _year = '';
  String? _type;
  String? _quartile;
  String? _approvalStatus;
  String? _severity; // null = All · 'Any issue' · 'Errors' · 'Warnings'
  late Future<List<Map<String, dynamic>>> _outputs = fetchOutputs();
  late final Future<List<String>> _types = fetchDistinctOutputTypes();

  void _load() {
    final year = int.tryParse(_year);
    setState(
      () => _outputs = fetchOutputs(
        query: _query,
        year: year,
        type: _type,
        quartile: _quartile,
        approvalStatus: _approvalStatus,
      ),
    );
  }

  void _search(String value) {
    _query = value;
    _load();
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
          FutureBuilder<List<String>>(
            future: _types,
            builder: (context, snapshot) {
              return _filters(snapshot.data ?? []);
            },
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

  Widget _filters(List<String> types) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ..._filterPills('Type', _type, types, (value) {
          _type = value;
          _load();
        }),
        ..._filterPills('Quartile', _quartile, const ['Q1', 'Q2', 'Q3', 'Q4'], (
          value,
        ) {
          _quartile = value;
          _load();
        }),
        ..._filterPills(
          'Approval',
          _approvalStatus,
          const ['pending', 'approved', 'rejected'],
          (value) {
            _approvalStatus = value;
            _load();
          },
        ),
        if (isAdmin)
          ..._filterPills('Issues', _severity, const [
            'Any issue',
            'Errors',
            'Warnings',
          ], (value) => setState(() => _severity = value)),
        TextButton.icon(
          onPressed: () => context.go('/conferences'),
          icon: const Icon(Icons.event),
          label: const Text('Conferences'),
        ),
      ],
    );
  }

  List<Widget> _filterPills(
    String label,
    String? selected,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      FilterPill(
        'All',
        selected: selected == null,
        onTap: () => onChanged(null),
      ),
      for (final value in values)
        FilterPill(
          value.replaceAll('_', ' '),
          selected: selected == value,
          onTap: () => onChanged(value),
        ),
    ];
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
      onTap: () => context.go('/outputs/${output['id']}'),
    );
  }
}
