import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/request_status.dart';
import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

/// Researcher-facing list of the signed-in user's own support requests
/// (funding/DPD/open-access/mission asks). Mirrors the req-card grid in
/// RAW_DATA/TemplatesFromCarmela/unidcom-researcher.html "Support requests".
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  late final Future<List<Map<String, dynamic>>> _requests = fetchMyRequests();

  @override
  Widget build(BuildContext context) {
    // No signed-out branch: /app/requests is auth-gated in main.dart, so an
    // anonymous visitor never reaches this widget.
    return AsyncView<List<Map<String, dynamic>>>(
      future: _requests,
      builder: (context, requests) {
        return ColoredBox(
          color: AppColors.pageBg,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Support requests',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => context.go('/app/requests/new'),
                        child: const Text('+ New request'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (requests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            mutedText(context, 'No requests yet.'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => context.go('/app/requests/new'),
                              child: const Text('+ New request'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final request in requests)
                          SizedBox(
                            width: 460,
                            child: _RequestCard(request: request),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

(PillTone, String) _typeStyle(String? type) => switch (type) {
  'dpd' => (PillTone.amber, 'DPD'),
  'open_access' => (PillTone.teal, 'Open Access'),
  'mission' => (PillTone.blue, 'Mission'),
  _ => (PillTone.grey, type ?? 'Unknown'),
};

PillTone _statusTone(String? status) => switch (status) {
  'draft' => PillTone.grey,
  'submitted' => PillTone.amber,
  'approved' => PillTone.teal,
  'rejected' => PillTone.red,
  'completed' => PillTone.blue,
  _ => PillTone.grey,
};

String _dateOnly(String? iso) =>
    (iso == null || iso.isEmpty) ? '' : iso.split('T').first;

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final id = request['id'] as String;
    final title = request['title'] as String? ?? 'Untitled request';
    final status = request['status'] as String? ?? 'draft';
    final (typeTone, typeLabel) = _typeStyle(request['type'] as String?);
    final eventName = request['event_name'] as String?;
    final eventDate = _dateOnly(request['event_date'] as String?);
    final meta = [
      if (eventName != null && eventName.isNotEmpty) eventName,
      if (eventDate.isNotEmpty) eventDate,
    ].join(' · ');
    final checklist = (request['checklist'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final done = checklist.where((item) => item['done'] == true).length;
    final createdAt = _dateOnly(request['created_at'] as String?);

    return Panel(
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TypeBadge(typeLabel, tone: typeTone),
                StatusPill(status, tone: _statusTone(status)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                meta,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            if (checklist.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: done / checklist.length,
                  minHeight: 4,
                  backgroundColor: AppColors.sandHoverStrong,
                  valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$done / ${checklist.length} documents',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    createdAt.isEmpty ? '' : 'Created $createdAt',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (ownerCanEdit(status))
                  TextButton(
                    onPressed: () => context.go('/app/requests/$id'),
                    child: const Text('Edit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
