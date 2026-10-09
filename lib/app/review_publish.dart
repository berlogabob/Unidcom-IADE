import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/review_session.dart';
import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/change_compare.dart';
import '../widgets/info_tip.dart';
import '../widgets/suggestion_tile.dart';

// Rui v1.1 (8 Oct 2026): "To review" and "Ready to publish" tabs.

const _siteUrl = 'https://berlogabob.github.io/unidcom-site/';

String _day(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  return d == null ? '' : dayLabel(d);
}

BoxDecoration _box() => BoxDecoration(
  color: AppColors.cardBg,
  border: Border.all(color: AppColors.cardBorder),
  borderRadius: BorderRadius.circular(8),
);

/// Tab "To review": who is waiting, then the researcher review (RP-*, RV-*).
class ToReviewTab extends StatefulWidget {
  const ToReviewTab({super.key});

  @override
  State<ToReviewTab> createState() => _ToReviewTabState();
}

class _ToReviewTabState extends State<ToReviewTab> {
  late Future<List<Map<String, dynamic>>> _queue = fetchReviewQueue();
  final _checked = DateTime.now();
  String _search = '';
  Map<String, dynamic>? _open;

  void _close() => setState(() {
    _open = null;
    _queue = fetchReviewQueue();
  });

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open != null) {
      return ResearcherReview(
        key: ValueKey(open['person_id']),
        person: open,
        onDone: _close,
      );
    }
    return FutureBuilder(
      future: _queue,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!
            .where(
              (r) =>
                  '${r['name']}'.toLowerCase().contains(_search.toLowerCase()),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.only(top: 12),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search name…',
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const Spacer(),
                Text('${rows.length} researchers to review'),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nothing to review · Last checked ${_checked.hour.toString().padLeft(2, '0')}:${_checked.minute.toString().padLeft(2, '0')}',
                ),
              ),
            for (final row in rows)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: _box(),
                child: ListTile(
                  title: Text('${row['name']}'),
                  subtitle: Text('submitted ${_day(row['submitted_at'])}'),
                  onTap: () => setState(() => _open = row),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One researcher's open items as Accept / Reject / Request change cards.
class ResearcherReview extends StatefulWidget {
  const ResearcherReview({
    super.key,
    required this.person,
    required this.onDone,
  });

  final Map<String, dynamic> person;
  final VoidCallback onDone;

  @override
  State<ResearcherReview> createState() => _ResearcherReviewState();
}

class _ResearcherReviewState extends State<ResearcherReview> {
  late final Future<List<Map<String, dynamic>>> _items = fetchReviewItems(
    '${widget.person['person_id']}',
  );
  ReviewSession? _session;
  final _byId = <String, Map<String, dynamic>>{};
  bool _saving = false;

  ReviewSession _init(List<Map<String, dynamic>> items) {
    for (final i in items) {
      _byId['${i['id']}'] = i;
    }
    return _session ??= ReviewSession([
      for (final i in items)
        ReviewItem(
          id: '${i['id']}',
          kind: i['kind'] == 'output' ? ReviewKind.output : ReviewKind.field,
        ),
    ]);
  }

  Future<void> _requestChange(String id) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What should the researcher change?'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Request change'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    setState(
      () => _session!.decide(id, ReviewDecision.changeRequested, comment: text),
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await finishReview(
        '${widget.person['person_id']}',
        _session!.toPayload(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review saved.')));
      widget.onDone();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Widget _card(Map<String, dynamic> item, ReviewSession s) {
    final id = '${item['id']}';
    final decision = s.decisionOf(id);
    final isOutput = item['kind'] == 'output';
    final title = isOutput
        ? 'New · ${item['type'] ?? 'Output'}${item['subtype'] == null ? '' : ' · ${item['subtype']}'}'
        : suggestionFieldLabel(item['field']);
    if (decision != null) {
      final label = switch (decision) {
        ReviewDecision.accepted => 'Accepted',
        ReviewDecision.rejected => 'Rejected',
        ReviewDecision.changeRequested => 'Change requested',
      };
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: _decided(),
        child: ListTile(
          dense: true,
          title: Text('$title — $label'),
          trailing: TextButton(
            onPressed: () => setState(() => s.undo(id)),
            child: const Text('Undo'),
          ),
        ),
      );
    }
    final current = item['current_value'] as String?;
    Widget body() => isOutput
        ? Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => context.go('/outputs/$id'),
                child: Text('${item['title']}'),
              ),
              Text(
                [
                  if (item['reporting_year'] != null)
                    ' · ${item['reporting_year']}',
                  item['doi'] == null
                      ? ' · DOI: — · Missing DOI'
                      : ' · DOI: ${item['doi']}',
                ].join(),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edited by researcher · ${_day(item['created_at'])}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              ChangeCompare(
                field: '${item['field']}',
                now: current,
                proposed: '${item['suggested_value'] ?? ''}',
              ),
            ],
          );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          body(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const InfoTip(
                  text:
                      'Accept sends it to Ready to publish. Reject or Request change sends it back to the researcher with your comment.',
                ),
                OutlinedButton(
                  onPressed: () => _requestChange(id),
                  child: const Text('Request change'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      setState(() => s.decide(id, ReviewDecision.rejected)),
                  child: const Text('Reject'),
                ),
                FilledButton(
                  onPressed: () =>
                      setState(() => s.decide(id, ReviewDecision.accepted)),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _decided() => _box().copyWith(color: AppColors.sandHover);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _items,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = _init(snap.data!);
        return ListView(
          padding: const EdgeInsets.only(top: 12),
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: widget.onDone,
                  child: const Text('← Back to To review'),
                ),
                Text(
                  '${widget.person['name']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () =>
                      context.go('/people/${widget.person['person_id']}'),
                  child: const Text('Open profile'),
                ),
              ],
            ),
            Text(
              'Decide each change: Accept, Reject or Request change. Then click Finish review.  ${s.decided} of ${s.total} decided',
            ),
            const SizedBox(height: 12),
            for (final item in s.ordered) _card(_byId[item.id]!, s),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(s.acceptAllRemaining),
                  child: const Text('Accept all remaining'),
                ),
                FilledButton(
                  onPressed: s.canFinish && !_saving ? _finish : null,
                  child: const Text('Finish review'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Tab "Ready to publish": pick researchers, publish in one batch (PB-*).
class ReadyToPublishTab extends StatefulWidget {
  const ReadyToPublishTab({super.key});

  @override
  State<ReadyToPublishTab> createState() => _ReadyToPublishTabState();
}

class _ReadyToPublishTabState extends State<ReadyToPublishTab> {
  late Future<List<Map<String, dynamic>>> _rows = fetchReadyToPublish();
  Set<String>? _selected; // null = all (default)
  bool _confirm = false;
  bool _busy = false;
  final _results = <String, Map<String, dynamic>>{};

  Future<void> _publish(List<String> ids) async {
    setState(() {
      _busy = true;
      _confirm = false;
    });
    try {
      for (final r in await publishResearchers(ids)) {
        _results['${r['id']}'] = r;
      }
      _rows = fetchReadyToPublish();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _rows,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        final ids = [for (final r in rows) '${r['id']}'];
        final sel = (_selected ?? ids.toSet()).intersection(ids.toSet());
        return ListView(
          padding: const EdgeInsets.only(top: 12),
          children: [
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => setState(
                    () => _selected = sel.length == ids.length
                        ? <String>{}
                        : ids.toSet(),
                  ),
                  child: const Text('Select all / none'),
                ),
                const Spacer(),
                Text('${sel.length} of ${ids.length} selected'),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nothing ready to publish.'),
              ),
            for (final r in rows)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: _box(),
                child: CheckboxListTile(
                  value: sel.contains('${r['id']}'),
                  onChanged: (v) => setState(() {
                    final next = {...sel};
                    v == true
                        ? next.add('${r['id']}')
                        : next.remove('${r['id']}');
                    _selected = next;
                  }),
                  title: Text('${r['preferred_name']}'),
                  subtitle: Text(
                    r['website_status'] == 'error'
                        ? 'Publication error · ${_results['${r['id']}']?['error'] ?? 'try again'}'
                        : 'approved ${_day(r['updated_at'])}',
                    style: TextStyle(
                      color: r['website_status'] == 'error'
                          ? AppColors.red
                          : null,
                    ),
                  ),
                  secondary: r['website_status'] == 'error'
                      ? TextButton(
                          onPressed: _busy
                              ? null
                              : () => _publish(['${r['id']}']),
                          child: const Text('Retry'),
                        )
                      : null,
                ),
              ),
            if (_results.values.any((r) => r['ok'] == true))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: _box(),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_results.values.where((r) => r['ok'] == true).length} researchers published. '
                        'The website shows them after the next sync (More → Website).',
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Check website'),
                      onPressed: () => launchUrl(
                        Uri.parse(_siteUrl),
                        webOnlyWindowName: '_blank',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (_confirm)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: _box(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Confirm: ${sel.length} researchers will be updated on the UNIDCOM website.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _confirm = false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => _publish(sel.toList()),
                      child: const Text('Publish'),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: sel.isEmpty || _busy
                      ? null
                      : () => setState(() => _confirm = true),
                  child: Text('Publish selected to website (${sel.length})'),
                ),
              ),
          ],
        );
      },
    );
  }
}
