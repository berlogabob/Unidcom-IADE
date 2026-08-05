import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../csv_download.dart';
import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

/// The report kinds the `report` Edge Function can render. `kind` is sent verbatim;
/// `usesTypeFilter` decides whether the Type dropdown applies to this report.
enum ReportKind {
  outputs('outputs', 'Scientific Outputs', usesTypeFilter: false),
  activities('activities', 'Relatorio de Atividades', usesTypeFilter: false),
  // The record-by-record reconciliation. Its own document rather than an appendix to
  // Scientific Outputs: bundled, the combined 28-page render tripped the Edge worker's
  // resource limit ~40% of the time. Per-section hygiene notes still appear in Outputs.
  review('review', 'Revisao de dados', usesTypeFilter: false),
  list('list', 'Listagem simples', usesTypeFilter: true);

  const ReportKind(this.kind, this.label, {required this.usesTypeFilter});
  final String kind;
  final String label;
  final bool usesTypeFilter;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final Future<List<Map<String, dynamic>>> _outputs =
      fetchOutputsForReport();
  int? _year;
  String? _type;
  ReportKind _kind = ReportKind.outputs;
  bool _generating = false;

  /// Calls the `report` Edge Function and hands the PDF straight to the browser.
  ///
  /// Retries up to 3 times. A cold Supabase worker has to fetch and compile ~28 MB of
  /// Typst wasm before it can render, which trips WORKER_RESOURCE_LIMIT for roughly one
  /// call in five; a retry lands on the now-warm worker. Measured over 10 sessions,
  /// 3 attempts succeeded every time and needed 13 calls in total.
  Future<void> _generatePdf() async {
    setState(() => _generating = true);
    try {
      final body = {
        'kind': _kind.kind,
        'year': _year,
        'filters': {
          if (_kind.usesTypeFilter && _type != null) 'type': _type,
        },
      };

      Uint8List? bytes;
      Object? lastError;
      for (var attempt = 0; attempt < 3 && bytes == null; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 800));
        }
        try {
          final res = await Supabase.instance.client.functions.invoke(
            'report',
            body: body,
          );
          final data = res.data;
          if (data is List<int>) bytes = Uint8List.fromList(data);
        } catch (error) {
          lastError = error;
        }
      }
      if (bytes == null) throw Exception(lastError ?? 'Empty response');

      final name = 'unidcom-${_kind.kind}-${_year ?? 'todos'}.pdf';
      if (!downloadBytes(name, bytes, 'application/pdf') && mounted) {
        _snack('PDF download is available on web.');
      }
    } catch (error) {
      if (mounted) _snack('Could not generate the PDF: $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _snack(String message) => showSnack(context, message);

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Map<String, dynamic>>>(
      future: _outputs,
      builder: (context, outputs) {
        final years =
            outputs
                .map((output) => output['reporting_year'] as int?)
                .whereType<int>()
                .toSet()
                .toList()
              ..sort((a, b) => b.compareTo(a));
        final types =
            outputs
                .map((output) => (output['type'] as String?)?.trim())
                .whereType<String>()
                .where((type) => type.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        // Mirrors what the Edge Function will put in the PDF: the Type filter only
        // applies to the kinds that expose it.
        final filtered = outputs.where((output) {
          return (_year == null || output['reporting_year'] == _year) &&
              (!_kind.usesTypeFilter ||
                  _type == null ||
                  output['type'] == _type);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<ReportKind>(
                      initialValue: _kind,
                      decoration: const InputDecoration(
                        labelText: 'Report',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final kind in ReportKind.values)
                          DropdownMenuItem(value: kind, child: Text(kind.label)),
                      ],
                      onChanged: (value) => setState(() {
                        _kind = value ?? ReportKind.outputs;
                        // The Type filter only exists for the simple listing.
                        if (!_kind.usesTypeFilter) _type = null;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        for (final year in years)
                          DropdownMenuItem(value: year, child: Text('$year')),
                      ],
                      onChanged: (value) => setState(() => _year = value),
                    ),
                  ),
                  if (_kind.usesTypeFilter)
                    SizedBox(
                      width: 320,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All'),
                          ),
                          for (final type in types)
                            DropdownMenuItem(value: type, child: Text(type)),
                        ],
                        onChanged: (value) => setState(() => _type = value),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generatePdf,
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_generating ? 'Generating…' : 'Generate PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: filtered.isEmpty
                        ? null
                        : () {
                            final ok = downloadCsv(
                              'unidcom_outputs_report.csv',
                              _csv(filtered),
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'CSV download is available on web.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.download),
                    label: const Text('Download CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Panel(
                  title: 'Outputs (${filtered.length})',
                  padding: const EdgeInsets.all(0),
                  child: filtered.isEmpty
                      ? const Center(child: Text('No outputs found'))
                      : Scrollbar(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Title')),
                                  DataColumn(label: Text('Year')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Subtype')),
                                  DataColumn(label: Text('Authors')),
                                  DataColumn(label: Text('DOI / URL')),
                                ],
                                rows: [
                                  for (final output in filtered)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 360,
                                            ),
                                            child: Text(
                                              output['title'] as String? ?? '',
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${output['reporting_year'] ?? ''}',
                                          ),
                                        ),
                                        DataCell(
                                          Text(output['type'] as String? ?? ''),
                                        ),
                                        DataCell(
                                          Text(
                                            output['subtype'] as String? ?? '',
                                          ),
                                        ),
                                        DataCell(Text(_authors(output))),
                                        DataCell(Text(_doiOrUrl(output))),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _csv(List<Map<String, dynamic>> outputs) {
  final rows = [
    ['title', 'reporting_year', 'type', 'subtype', 'authors', 'doi_url'],
    for (final output in outputs)
      [
        output['title'],
        output['reporting_year'],
        output['type'],
        output['subtype'],
        _authors(output),
        _doiOrUrl(output),
      ],
  ];
  return rows
      .map((row) => row.map((value) => _csvCell('${value ?? ''}')).join(','))
      .join('\n');
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _authors(Map<String, dynamic> output) {
  return (output['output_authors'] as List<dynamic>? ?? [])
      .map((author) {
        final person = (author as Map<String, dynamic>)['people'];
        return (person as Map<String, dynamic>?)?['preferred_name'] as String?;
      })
      .whereType<String>()
      .join(', ');
}

String _doiOrUrl(Map<String, dynamic> output) {
  final doi = (output['doi'] as String?)?.trim();
  if (doi != null && doi.isNotEmpty) return doi;
  return (output['url'] as String?)?.trim() ?? '';
}
