import 'package:flutter/material.dart';

import '../csv_download.dart';
import '../data/news_taxonomy.dart';
import '../data/news_template.dart';
import '../data/supabase.dart';
import 'news_wizard.dart';

Future<bool?> showNewsImport(BuildContext context) async {
  if (!canPublishNews()) return false;
  try {
    final file = await pickNewsFile();
    if (file == null) return false;
    final slugs = await fetchArticleSlugs();
    final parsed = parseNewsFile(file.bytes, file.name, existingSlugs: slugs);
    if (!context.mounted) return false;
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 1000,
          height: 720,
          child: NewsImportPreview(result: parsed),
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
    return false;
  }
}

class NewsImportPreview extends StatefulWidget {
  const NewsImportPreview({
    super.key,
    required this.result,
    this.canEdit = canPublishNews,
    this.importRows = importNewsDrafts,
  });
  final NewsParseResult result;
  final bool Function() canEdit;
  final Future<int> Function(List<NewsImportRow>) importRows;

  @override
  State<NewsImportPreview> createState() => _NewsImportPreviewState();
}

class _NewsImportPreviewState extends State<NewsImportPreview> {
  late final List<NewsImportRow> _rows = [...widget.result.rows];
  final _skipped = <int>{};
  bool _busy = false;
  bool _finished = false;
  int _inserted = 0;
  String? _error;

  List<NewsImportRow> get _selected =>
      _rows.where((r) => !_skipped.contains(r.rowNumber)).toList();
  Map<int, List<String>> get _fileMessages => {
    for (final e in widget.result.errors.entries)
      if (!_rows.any((r) => r.rowNumber == e.key)) e.key: e.value,
  };
  bool get _fileBlocked => _fileMessages.values.any(
    (messages) => messages.any((m) => m != 'duplicate title+year'),
  );

  void _fix(int index, String key, String value) {
    final row = _rows[index];
    final data = {
      ...row.data,
      key: key == 'lab' ? [value] : value,
    };
    final warnings = row.warnings
        .where(
          (w) => key == 'lab'
              ? w != 'missing lab'
              : !w.startsWith('Unclassified type:'),
        )
        .toList();
    // Keep import_note as the original provenance, even after an inline correction.
    setState(
      () => _rows[index] = NewsImportRow(
        row.rowNumber,
        data,
        row.errors,
        warnings,
      ),
    );
  }

  Future<void> _confirm() async {
    final rows = _selected;
    if (_busy ||
        rows.isEmpty ||
        rows.any((r) => r.errors.isNotEmpty) ||
        _fileBlocked ||
        !widget.canEdit()) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import news drafts?'),
        content: Text(
          '${rows.length} news items will be saved as unpublished drafts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import drafts'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || !widget.canEdit()) return;
    setState(() => _busy = true);
    try {
      // Match Task A's atomic batch size, exposing progress between batches.
      for (var start = 0; start < rows.length; start += 100) {
        if (!widget.canEdit()) throw StateError('Admin access required');
        final count = await widget.importRows(
          rows.sublist(start, (start + 100).clamp(0, rows.length)),
        );
        if (!mounted) return;
        setState(() => _inserted += count);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Import stopped after $_inserted drafts. Earlier batches remain. Refresh existing slugs and review partial imports before retrying. $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _finished = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canEdit()) {
      return const Center(child: Text('Admin access required'));
    }
    final duplicates = _fileMessages.values
        .where((m) => m.contains('duplicate title+year'))
        .length;
    final ok = _rows
        .where((r) => r.errors.isEmpty && r.warnings.isEmpty)
        .length;
    final warnings = _rows
        .where((r) => r.errors.isEmpty && r.warnings.isNotEmpty)
        .length;
    final errors =
        _rows.where((r) => r.errors.isNotEmpty).length +
        _fileMessages.values
            .where((m) => !m.contains('duplicate title+year'))
            .length;
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Import filled template',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'OK: $ok · Warnings: $warnings · Errors: $errors · Duplicates: $duplicates',
              key: const ValueKey('import-counts'),
            ),
            const Text(
              'Duplicates are omitted. Correct warnings here or skip rows. Rows with errors must be skipped or corrected in the file.',
            ),
            if (_finished) ...[
              Text('Inserted: $_inserted unpublished drafts.'),
              if (_error != null) Text(_error!),
            ],
            if (_busy) ...[
              LinearProgressIndicator(
                value: _selected.isEmpty ? 0 : _inserted / _selected.length,
              ),
              Text('Imported $_inserted of ${_selected.length} drafts…'),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      for (final label in [
                        'Skip',
                        'Row',
                        'Title',
                        'Date',
                        'Type',
                        'Lab',
                        'Messages',
                      ])
                        DataColumn(label: Text(label)),
                    ],
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 140,
                    rows: [
                      for (var i = 0; i < _rows.length; i++) _row(i),
                      for (final entry in _fileMessages.entries)
                        DataRow(
                          cells: [
                            const DataCell(Text('—')),
                            DataCell(Text('${entry.key}')),
                            const DataCell(Text('—')),
                            const DataCell(Text('—')),
                            const DataCell(Text('—')),
                            const DataCell(Text('—')),
                            DataCell(
                              SizedBox(
                                width: 280,
                                child: Text(entry.value.join('; ')),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (!_finished)
                  FilledButton(
                    onPressed:
                        !_busy &&
                            !_fileBlocked &&
                            _selected.isNotEmpty &&
                            _selected.every((r) => r.errors.isEmpty)
                        ? _confirm
                        : null,
                    child: Text('Import ${_selected.length} drafts'),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(_finished),
                  child: Text(_finished ? 'Done' : 'Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DataRow _row(int index) {
    final row = _rows[index];
    final skipped = _skipped.contains(row.rowNumber);
    final editable = !_busy && !_finished && !skipped;
    return DataRow(
      cells: [
        DataCell(
          Checkbox(
            key: ValueKey('skip-${row.rowNumber}'),
            value: skipped,
            onChanged: _busy || _finished
                ? null
                : (v) => setState(() {
                    v!
                        ? _skipped.add(row.rowNumber)
                        : _skipped.remove(row.rowNumber);
                  }),
          ),
        ),
        DataCell(Text('${row.rowNumber}')),
        DataCell(SizedBox(width: 200, child: Text('${row.data['title']}'))),
        DataCell(Text('${row.data['year'] ?? 'Missing'}')),
        DataCell(
          row.data['news_type'] == 'Unclassified'
              ? SizedBox(
                  width: 210,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: 'Unclassified',
                    items: [
                      for (final type in newsTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: editable
                        ? (v) {
                            if (v != null && v != 'Unclassified') {
                              _fix(index, 'news_type', v);
                            }
                          }
                        : null,
                  ),
                )
              : Text('${row.data['news_type']}'),
        ),
        DataCell(
          (row.data['lab'] as List?)?.isNotEmpty == true
              ? Text((row.data['lab'] as List).join(', '))
              : SizedBox(
                  width: 110,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Missing lab'),
                    items: [
                      for (final lab in newsLabs)
                        DropdownMenuItem(value: lab, child: Text(lab)),
                    ],
                    onChanged: editable
                        ? (v) {
                            if (v != null) _fix(index, 'lab', v);
                          }
                        : null,
                  ),
                ),
        ),
        DataCell(
          SizedBox(
            width: 280,
            child: Text(
              [
                if (skipped) 'Skipped',
                ...row.errors,
                ...row.warnings,
                if (row.errors.isEmpty && row.warnings.isEmpty) 'OK',
              ].join('; '),
            ),
          ),
        ),
      ],
    );
  }
}
