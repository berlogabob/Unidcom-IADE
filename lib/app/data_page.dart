import 'dart:convert';

import 'package:flutter/material.dart';

import '../csv_download.dart';
import '../data/supabase.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _busy = false;
  String _table = dbTables.first;
  late Future<List<Map<String, dynamic>>> _rows = fetchTable(_table);

  void _selectTable(String? table) {
    if (table == null) return;
    setState(() {
      _table = table;
      _rows = fetchTable(table);
    });
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await exportAll();
      final ok = downloadText(
        'unidcom_db_export.json',
        const JsonEncoder.withIndent('  ').convert(data),
        'application/json',
      );
      _snack(ok ? 'Exported.' : 'Download is available on web.');
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final text = await pickTextFile();
      if (text == null) {
        _snack('No file selected (or import is web-only).');
        return;
      }
      final decoded = (jsonDecode(text) as Map<String, dynamic>).map(
        (table, rows) => MapEntry(
          table,
          (rows as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList(),
        ),
      );
      if (!mounted) return;
      final counts = dbTables
          .where((table) => (decoded[table]?.isNotEmpty ?? false))
          .map((table) => '$table: ${decoded[table]!.length}')
          .join('\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import (upsert)?'),
          content: Text(
            'This inserts new rows and updates existing ones by primary key. '
            'Nothing is deleted.\n\n${counts.isEmpty ? 'No known tables found.' : counts}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: counts.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await importAll(decoded);
      _snack('Import complete.');
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Back up or migrate the whole database as JSON. '
            'Import upserts by primary key — it never deletes.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.download),
                label: const Text('Export all to JSON'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import from JSON'),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          const Divider(height: 32),
          Row(
            children: [
              const Text('Browse table:'),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _table,
                items: [
                  for (final table in dbTables)
                    DropdownMenuItem(value: table, child: Text(table)),
                ],
                onChanged: _selectTable,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _TableView(future: _rows)),
        ],
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.future});

  final Future<List<Map<String, dynamic>>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return const Center(child: Text('No rows'));
        // Column set = union of keys across rows, minus the noisy tsvector.
        final columns =
            <String>{for (final row in rows) ...row.keys}
              ..remove('search');
        final cols = columns.toList();
        // ponytail: render all rows (<=360 at lab scale); paginate only if a
        // table ever grows large.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${rows.length} rows'),
            const SizedBox(height: 4),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: [
                        for (final col in cols) DataColumn(label: Text(col)),
                      ],
                      rows: [
                        for (final row in rows)
                          DataRow(
                            cells: [
                              for (final col in cols)
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                    ),
                                    child: Text('${row[col] ?? ''}'),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
