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
        ],
      ),
    );
  }
}
