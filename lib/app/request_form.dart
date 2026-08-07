import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/request_status.dart';
import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

/// (column value, display label) for the request-type selector.
const _requestTypes = [
  ('dpd', 'DPD'),
  ('open_access', 'Open Access'),
  ('mission', 'Mission'),
];

const _presentationFormats = ['Oral', 'Poster', 'Panel', 'Other'];

const _dpdChecklistItems = [
  'Invitation or acceptance letter',
  'Program or agenda',
  'Budget estimate',
  'DPD form',
];

List<Map<String, dynamic>> _defaultChecklist() => [
  for (final item in _dpdChecklistItems) {'item': item, 'done': false},
];

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// One label+amount row in the budget block; owns its own controllers so
/// rows can be added/removed freely.
class _BudgetLine {
  _BudgetLine({String? label, String? amount})
    : labelController = TextEditingController(text: label),
      amountController = TextEditingController(text: amount);

  final TextEditingController labelController;
  final TextEditingController amountController;

  void dispose() {
    labelController.dispose();
    amountController.dispose();
  }
}

/// Create/edit a support request (DPD / Open Access / Mission ask).
/// [requestId] null = new request; otherwise loads and edits an existing one
/// (via [fetchMyRequests], the owner-scoped list — RLS keeps this to "my own").
class RequestFormPage extends StatefulWidget {
  const RequestFormPage({super.key, this.requestId});

  final String? requestId;

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  final _titleController = TextEditingController();
  final _eventNameController = TextEditingController();
  final _eventUrlController = TextEditingController();
  final _locationController = TextEditingController();

  String _type = 'dpd';
  DateTime? _eventDate;
  String _presentationFormat = _presentationFormats.first;
  List<_BudgetLine> _budgetLines = [_BudgetLine()];
  List<Map<String, dynamic>> _checklist = _defaultChecklist();

  String? _id;
  String _status = 'draft';
  bool _loaded = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.requestId == null) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final rows = await fetchMyRequests();
      final row = rows.firstWhere(
        (r) => r['id'] == widget.requestId,
        orElse: () => <String, dynamic>{},
      );
      if (row.isEmpty) {
        setState(() {
          _loadError = 'Request not found';
          _loaded = true;
        });
        return;
      }
      _id = row['id'] as String?;
      _status = row['status'] as String? ?? 'draft';
      _type = row['type'] as String? ?? 'dpd';
      _titleController.text = row['title'] as String? ?? '';
      _eventNameController.text = row['event_name'] as String? ?? '';
      _eventUrlController.text = row['event_url'] as String? ?? '';
      _locationController.text = row['location'] as String? ?? '';
      final dateStr = row['event_date'] as String?;
      _eventDate = dateStr == null ? null : DateTime.tryParse(dateStr);
      final format = row['presentation_format'] as String?;
      _presentationFormat = _presentationFormats.contains(format)
          ? format!
          : _presentationFormats.first;
      final budget = row['budget'] as Map<String, dynamic>?;
      if (budget != null && budget.isNotEmpty) {
        for (final line in _budgetLines) {
          line.dispose();
        }
        _budgetLines = budget.entries
            .map(
              (entry) =>
                  _BudgetLine(label: entry.key, amount: '${entry.value}'),
            )
            .toList();
      }
      final checklist = row['checklist'] as List<dynamic>?;
      if (checklist != null && checklist.isNotEmpty) {
        _checklist = checklist
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      if (!mounted) return;
      setState(() => _loaded = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _eventNameController.dispose();
    _eventUrlController.dispose();
    _locationController.dispose();
    for (final line in _budgetLines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _total {
    var sum = 0.0;
    for (final line in _budgetLines) {
      sum += double.tryParse(line.amountController.text.trim()) ?? 0;
    }
    return sum;
  }

  // Keys must stay unique — the map's keys are the stored budget labels, so
  // two lines with the same label would otherwise collapse into one entry
  // (last wins) and disagree with the total shown on screen.
  Map<String, dynamic> get _budgetMap {
    final map = <String, dynamic>{};
    final seen = <String, int>{};
    for (final line in _budgetLines) {
      final label = line.labelController.text.trim();
      final amount = double.tryParse(line.amountController.text.trim());
      if (label.isEmpty || amount == null) continue;
      var key = label;
      if (map.containsKey(key)) {
        final n = (seen[label] ?? 1) + 1;
        seen[label] = n;
        key = '$label ($n)';
      }
      map[key] = amount;
    }
    return map;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _eventDate = picked);
  }

  Map<String, dynamic> _fields() => {
    'type': _type,
    'title': _titleController.text.trim(),
    'event_name': _eventNameController.text.trim(),
    'event_url': _eventUrlController.text.trim(),
    'event_date': _eventDate == null ? null : _formatDate(_eventDate!),
    'location': _locationController.text.trim(),
    'presentation_format': _presentationFormat,
    'budget': _budgetMap,
    'amount_total': _total,
    'checklist': _type == 'dpd' ? _checklist : <Map<String, dynamic>>[],
  };

  bool _validate() {
    if (_titleController.text.trim().isEmpty) {
      showSnack(context, 'Title is required');
      return false;
    }
    return true;
  }

  Future<void> _save({bool submit = false}) async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    try {
      final fields = _fields();
      final id = _id == null
          ? (await createRequest(fields))['id'] as String
          : _id!;
      if (_id != null) await updateRequest(_id!, fields);
      if (submit) await submitRequest(id);
      if (!mounted) return;
      context.go('/app/requests');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped by AppShell (Scaffold + app bar + bottom nav) — no Scaffold here.
    if (db.auth.currentUser == null) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sign in to create a support request.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_loaded) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.tealDark),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Text(
          _loadError!,
          style: const TextStyle(color: AppColors.red),
        ),
      );
    }

    final readOnly = widget.requestId != null && !ownerCanEdit(_status);
    final canSubmit = ownerCanSubmit(_status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (readOnly)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amberTintSoft,
                      borderRadius: BorderRadius.circular(AppDims.radiusSm),
                    ),
                    child: const Text(
                      'This request can no longer be edited.',
                      style: TextStyle(color: AppColors.amberDark),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _requestTypes)
                      FilterPill(
                        entry.$2,
                        selected: _type == entry.$1,
                        onTap: readOnly
                            ? () {}
                            : () => setState(() => _type = entry.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Panel(
                  title: 'Event details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _textField(
                        'Title',
                        _titleController,
                        readOnly: readOnly,
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        'Event name',
                        _eventNameController,
                        readOnly: readOnly,
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        'Event URL',
                        _eventUrlController,
                        readOnly: readOnly,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: readOnly ? null : _pickDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Event date',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _eventDate == null
                                      ? 'Not set'
                                      : _formatDate(_eventDate!),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _textField(
                              'Location',
                              _locationController,
                              readOnly: readOnly,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _presentationFormat,
                        decoration: const InputDecoration(
                          labelText: 'Presentation format',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final format in _presentationFormats)
                            DropdownMenuItem(
                              value: format,
                              child: Text(format),
                            ),
                        ],
                        onChanged: readOnly
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _presentationFormat = value);
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  title: 'Budget',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _budgetLines.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _budgetLines[i].labelController,
                                  readOnly: readOnly,
                                  decoration: const InputDecoration(
                                    labelText: 'Label',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _budgetLines[i].amountController,
                                  readOnly: readOnly,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              if (!readOnly)
                                IconButton(
                                  tooltip: 'Remove line',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() {
                                    _budgetLines[i].dispose();
                                    _budgetLines.removeAt(i);
                                  }),
                                ),
                            ],
                          ),
                        ),
                      if (!readOnly)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(
                              () => _budgetLines.add(_BudgetLine()),
                            ),
                            child: const Text('+ Add line'),
                          ),
                        ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total requested',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _total.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_type == 'dpd') ...[
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Checklist',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ChecklistProgress(items: _checklist),
                        const SizedBox(height: 8),
                        for (var i = 0; i < _checklist.length; i++)
                          CheckboxListTile(
                            value: _checklist[i]['done'] as bool? ?? false,
                            onChanged: readOnly
                                ? null
                                : (value) => setState(
                                    () =>
                                        _checklist[i]['done'] = value ?? false,
                                  ),
                            title: Text(_checklist[i]['item'] as String? ?? ''),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: (readOnly || _saving) ? null : () => _save(),
                      child: const Text('Save draft'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: (readOnly || _saving || !canSubmit)
                          ? null
                          : () => _save(submit: true),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _textField(
  String label,
  TextEditingController controller, {
  bool readOnly = false,
  bool required = false,
}) {
  return TextField(
    controller: controller,
    readOnly: readOnly,
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      border: const OutlineInputBorder(),
    ),
  );
}

/// Thin progress bar + "N of M items complete" label above the checklist.
class _ChecklistProgress extends StatelessWidget {
  const _ChecklistProgress({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final done = items.where((item) => item['done'] == true).length;
    final ratio = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.greyTint,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$done of $total items complete',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
