import 'package:flutter/material.dart';

import 'pick_matrix.dart';

/// An ordered field to compare/pick in a merge matrix. `tall` widens the
/// cell's maxLines for long text (title, bio, full_reference, ...).
typedef MergeFieldSpec = ({String key, String label, bool tall});

const personMergeFields = <MergeFieldSpec>[
  (key: 'preferred_name', label: 'Preferred name', tall: false),
  (key: 'legal_name', label: 'Legal name', tall: false),
  (key: 'email', label: 'Email', tall: false),
  (key: 'orcid', label: 'ORCID', tall: false),
  (key: 'ciencia_id', label: 'Ciencia ID', tall: false),
  (key: 'membership_type', label: 'Membership type', tall: false),
  (key: 'status', label: 'Status', tall: false),
  (key: 'bio', label: 'Bio', tall: true),
  (key: 'photo_url', label: 'Photo URL', tall: false),
];

const outputMergeFields = <MergeFieldSpec>[
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

/// Shared merge-review dialog: a DataTable with a SURVIVOR radio row plus one
/// radio row per [fields] entry, a live [ResultPreview] side panel, and a
/// confirmation step before calling [onMerge]. Generalizes the original
/// people-only `_MergeMatrixDialog` so any record type (people, outputs, ...)
/// can reuse the exact same UI/interaction.
class MergeMatrixDialog extends StatefulWidget {
  const MergeMatrixDialog({
    super.key,
    required this.title,
    required this.records,
    required this.fields,
    required this.nameOf,
    required this.onMerge,
  });

  final String title;
  final List<Map<String, dynamic>> records;
  final List<MergeFieldSpec> fields;
  final String Function(Map<String, dynamic> record) nameOf;
  final Future<void> Function(
    String survivorId,
    List<String> loserIds,
    Map<String, dynamic> fields,
  )
  onMerge;

  @override
  State<MergeMatrixDialog> createState() => _MergeMatrixDialogState();
}

class _MergeMatrixDialogState extends State<MergeMatrixDialog> {
  late String _survivorId = widget.records.first['id'] as String;
  late final _choice = {
    for (final field in widget.fields) field.key: _defaultChoice(field.key),
  };
  bool _saving = false;

  String _defaultChoice(String field) {
    final survivor = widget.records.firstWhere((r) => r['id'] == _survivorId);
    if (_value(survivor, field).isNotEmpty) return _survivorId;
    return (widget.records.firstWhere(
          (record) => _value(record, field).isNotEmpty,
          orElse: () => survivor,
        )['id']
        as String);
  }

  String _value(Map<String, dynamic> record, String field) =>
      (record[field]?.toString() ?? '').trim();

  void _setSurvivor(String id) {
    setState(() {
      _survivorId = id;
      for (final field in widget.fields) {
        _choice[field.key] = _defaultChoice(field.key);
      }
    });
  }

  Future<void> _merge() async {
    final survivor = widget.records.firstWhere((r) => r['id'] == _survivorId);
    final losers = widget.records.where((r) => r['id'] != _survivorId).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge records?'),
        content: Text(
          'This merges ${losers.map(widget.nameOf).join(', ')} into '
          '${widget.nameOf(survivor)}. The others become hidden (reversible). '
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final fields = {
        for (final field in widget.fields)
          field.key: _value(
            widget.records.firstWhere((r) => r['id'] == _choice[field.key]),
            field.key,
          ),
      };
      await widget.onMerge(
        _survivorId,
        losers.map((r) => r['id'] as String).toList(),
        fields,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Merged ${widget.records.length} records into '
            '${widget.nameOf(survivor)}',
          ),
        ),
      );
      Navigator.of(context).pop(true);
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
    String? tallField;
    for (final field in widget.fields) {
      if (field.tall) {
        tallField = field.key;
        break;
      }
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: [
                                const DataColumn(label: Text('Field')),
                                for (final record in widget.records)
                                  DataColumn(
                                    label: SizedBox(
                                      width: 180,
                                      child: Text(
                                        widget.nameOf(record),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                              rows: [
                                DataRow(
                                  cells: [
                                    const DataCell(Text('SURVIVOR')),
                                    for (final record in widget.records)
                                      DataCell(
                                        RadioChoice(
                                          selected:
                                              record['id'] as String ==
                                              _survivorId,
                                          onTap: _saving
                                              ? null
                                              : () => _setSurvivor(
                                                  record['id'] as String,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                                for (final field in widget.fields)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(field.label)),
                                      for (final record in widget.records)
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: RadioChoice(
                                              selected:
                                                  record['id'] as String ==
                                                  _choice[field.key],
                                              onTap: _saving
                                                  ? null
                                                  : () => setState(
                                                      () => _choice[field.key] =
                                                          record['id']
                                                              as String,
                                                    ),
                                              child: Text(
                                                _value(
                                                      record,
                                                      field.key,
                                                    ).isEmpty
                                                    ? '-'
                                                    : _value(record, field.key),
                                                maxLines: field.tall ? 4 : 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
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
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: ResultPreview(
                        fields: [
                          for (final field in widget.fields)
                            (field.key, field.label),
                        ],
                        tallField: tallField,
                        values: {
                          for (final field in widget.fields)
                            field.key: _value(
                              widget.records.firstWhere(
                                (r) => r['id'] == _choice[field.key],
                              ),
                              field.key,
                            ),
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _merge,
                    child: Text(
                      _saving
                          ? 'Merging...'
                          : 'Merge ${widget.records.length} records',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
