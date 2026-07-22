import 'package:flutter/material.dart';

import '../csv_download.dart';
import '../data/supabase.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _outputs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final outputs = snapshot.data ?? [];
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
        final filtered = outputs.where((output) {
          return (_year == null || output['reporting_year'] == _year) &&
              (_type == null || output['type'] == _type);
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
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All')),
                        for (final type in types)
                          DropdownMenuItem(value: type, child: Text(type)),
                      ],
                      onChanged: (value) => setState(() => _type = value),
                    ),
                  ),
                  FilledButton.icon(
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
              Text('${filtered.length} outputs'),
              const SizedBox(height: 4),
              const Text("For a PDF, use your browser's Print -> Save as PDF."),
              const SizedBox(height: 12),
              Expanded(
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
