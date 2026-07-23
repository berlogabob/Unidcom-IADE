import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/pick_matrix.dart';

const _fields = [
  ('bio', 'Bio'),
  ('legal_name', 'Legal name'),
  ('email', 'Email'),
  ('ciencia_id', 'Ciencia ID'),
  ('orcid', 'ORCID'),
];

String _val(Map<String, dynamic> source, String field) =>
    (source[field] as String?)?.trim() ?? '';

/// Opens the ORCID update matrix for [personId]: Current (app) vs. ORCID
/// (incoming) per field, pick which wins, apply. Only fields where ORCID has a
/// value that differs from (or fills) the current one are shown. Returns true
/// if changes were applied. If nothing differs, shows a snackbar and returns
/// false without opening the dialog.
Future<bool> showOrcidUpdateDialog(
  BuildContext context, {
  required String personId,
  required Map<String, dynamic> current,
  required Map<String, String> incoming,
}) async {
  final rows = [
    for (final field in _fields)
      if (_val(incoming, field.$1).isNotEmpty &&
          _val(incoming, field.$1) != _val(current, field.$1))
        field,
  ];
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Already up to date with ORCID')),
    );
    return false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (context) => _UpdateMatrixDialog(
          personId: personId,
          current: current,
          incoming: incoming,
          rows: rows,
        ),
      ) ??
      false;
}

class _UpdateMatrixDialog extends StatefulWidget {
  const _UpdateMatrixDialog({
    required this.personId,
    required this.current,
    required this.incoming,
    required this.rows,
  });

  final String personId;
  final Map<String, dynamic> current;
  final Map<String, String> incoming;
  final List<(String, String)> rows;

  @override
  State<_UpdateMatrixDialog> createState() => _UpdateMatrixDialogState();
}

class _UpdateMatrixDialogState extends State<_UpdateMatrixDialog> {
  // Per field: true = take ORCID value, false = keep current. Default keeps the
  // current value unless it is empty (then take the incoming ORCID value).
  late final Map<String, bool> _takeOrcid = {
    for (final field in widget.rows)
      field.$1: _val(widget.current, field.$1).isEmpty,
  };
  bool _saving = false;

  String _chosen(String field) => (_takeOrcid[field] ?? false)
      ? _val(widget.incoming, field)
      : _val(widget.current, field);

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      final chosen = <String, dynamic>{
        for (final field in widget.rows) field.$1: _chosen(field.$1),
      };
      await updatePerson(widget.personId, {
        ...chosen,
        'last_verified_at': DateTime.now().toIso8601String(),
      });
      await logChanges(
        'person',
        widget.personId,
        widget.current,
        chosen,
        source: 'orcid',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${widget.rows.length} field(s) from ORCID')),
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

  DataCell _cell(String field, {required bool orcid}) {
    final source = orcid ? widget.incoming : widget.current;
    final value = _val(source, field);
    return DataCell(
      SizedBox(
        width: 260,
        child: RadioChoice(
          selected: (_takeOrcid[field] ?? false) == orcid,
          onTap: _saving
              ? null
              : () => setState(() => _takeOrcid[field] = orcid),
          child: Text(
            value.isEmpty ? '-' : value,
            maxLines: field == 'bio' ? 4 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update from ORCID',
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
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Field')),
                              DataColumn(label: Text('Current')),
                              DataColumn(label: Text('ORCID')),
                            ],
                            rows: [
                              for (final field in widget.rows)
                                DataRow(
                                  cells: [
                                    DataCell(Text(field.$2)),
                                    _cell(field.$1, orcid: false),
                                    _cell(field.$1, orcid: true),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: ResultPreview(
                        fields: widget.rows,
                        tallField: 'bio',
                        values: {
                          for (final field in widget.rows)
                            field.$1: _chosen(field.$1),
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
                    onPressed: _saving ? null : _apply,
                    child: Text(_saving ? 'Applying...' : 'Apply'),
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
