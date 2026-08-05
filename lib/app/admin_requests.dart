import 'package:flutter/material.dart';

import '../data/request_status.dart';
import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

/// Admin triage of support requests (`support_requests`): stat cards,
/// status filter pills, and a table with per-row approve/reject/complete
/// actions driven by [adminNextStatuses].
class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  late Future<List<Map<String, dynamic>>> _requests = fetchAllRequests();
  String? _filter; // null = All

  void _refresh() {
    setState(() => _requests = fetchAllRequests());
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await setRequestStatus(id, status);
      if (!mounted) return;
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showSnack(context, error.toString());
    }
  }

  Future<void> _reject(String id) async {
    final controller = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject request'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Admin note (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final note = controller.text.trim();
      await setRequestStatus(
        id,
        'rejected',
        adminNote: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showSnack(context, error.toString());
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final all = snapshot.data ?? const [];
          final filtered = _filter == null
              ? all
              : all.where((r) => r['status'] == _filter).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AccentStatCard(
                      label: 'Submitted',
                      value: '${_countByStatus(all, 'submitted')}',
                      tone: AccentTone.warn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AccentStatCard(
                      label: 'Approved',
                      value: '${_countByStatus(all, 'approved')}',
                      tone: AccentTone.good,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AccentStatCard(
                      label: 'Completed',
                      value: '${_countByStatus(all, 'completed')}',
                      tone: AccentTone.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterPill(
                    'All',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final status in const [
                    'submitted',
                    'approved',
                    'rejected',
                    'completed',
                  ])
                    FilterPill(
                      _capitalize(status),
                      selected: _filter == status,
                      onTap: () => setState(() => _filter = status),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Panel(
                    title: 'Requests',
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No requests.',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < filtered.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 24,
                                    color: AppColors.cardBorder,
                                  ),
                                _RequestRow(
                                  request: filtered[i],
                                  onSetStatus: _setStatus,
                                  onReject: _reject,
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.onSetStatus,
    required this.onReject,
  });

  final Map<String, dynamic> request;
  final void Function(String id, String status) onSetStatus;
  final void Function(String id) onReject;

  @override
  Widget build(BuildContext context) {
    final id = request['id'] as String? ?? '';
    final status = request['status'] as String? ?? 'draft';
    final type = request['type'] as String? ?? '';
    final title = request['title'] as String? ?? 'Untitled request';
    final personId = request['person_id'] as String?;
    final eventName = request['event_name'] as String?;
    final eventDate = request['event_date'] as String?;
    final amountTotal = request['amount_total'];

    final (typeLabel, typeTone) = _typeBadge(type);

    final metaParts = <String>[
      if (personId != null && personId.isNotEmpty)
        'Person #${personId.length > 8 ? personId.substring(0, 8) : personId}',
      if (eventName != null && eventName.isNotEmpty) eventName,
      if (eventDate != null && eventDate.isNotEmpty) eventDate,
      if (amountTotal != null) '€ ${_formatAmount(amountTotal)}',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TypeBadge(typeLabel, tone: typeTone),
                    const SizedBox(width: 8),
                    StatusPill(
                      _capitalize(status),
                      tone: _statusTone(status),
                    ),
                  ],
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    metaParts.join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final next in adminNextStatuses(status))
                if (next == 'rejected')
                  TextButton(
                    onPressed: () => onReject(id),
                    child: const Text('Reject'),
                  )
                else
                  FilledButton(
                    onPressed: () => onSetStatus(id, next),
                    child: Text(_actionLabel(next)),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

int _countByStatus(List<Map<String, dynamic>> requests, String status) =>
    requests.where((r) => r['status'] == status).length;

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _actionLabel(String status) => switch (status) {
  'approved' => 'Approve',
  'rejected' => 'Reject',
  'completed' => 'Complete',
  _ => _capitalize(status),
};

PillTone _statusTone(String status) => switch (status) {
  'draft' => PillTone.grey,
  'submitted' => PillTone.amber,
  'approved' => PillTone.teal,
  'rejected' => PillTone.red,
  'completed' => PillTone.blue,
  _ => PillTone.grey,
};

(String, PillTone) _typeBadge(String type) => switch (type) {
  'dpd' => ('DPD', PillTone.amber),
  'open_access' => ('Open Access', PillTone.teal),
  'mission' => ('Mission', PillTone.blue),
  _ => (type, PillTone.grey),
};

String _formatAmount(Object amount) {
  final value = amount is num ? amount : num.tryParse(amount.toString());
  if (value == null) return amount.toString();
  return value.toStringAsFixed(2);
}
