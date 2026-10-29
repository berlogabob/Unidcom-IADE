import 'package:flutter/material.dart';

import '../csv_download.dart';
import '../data/news_template.dart';
import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';
import 'news_import.dart';
import 'news_wizard.dart';

/// One kind of website content that has no other home in the portal.
class SiteContentKind {
  const SiteContentKind(
    this.table,
    this.label,
    this.fields, {
    this.subtitle,
    this.order = 'title',
  });

  final String table;
  final String label; // singular, e.g. 'funder'
  final List<EntityField> fields;
  final String? Function(Map<String, dynamic>)? subtitle;
  final String order;
}

final siteContentKinds = [
  SiteContentKind('funders', 'funder', const [
    EntityField('title', 'Name'),
    EntityField('logo_url', 'Logo', kind: EntityKind.image),
  ]),
  SiteContentKind(
    'articles',
    'article',
    const [
      EntityField('title', 'Title'),
      EntityField('slug', 'Slug (website address)'),
      EntityField('date', 'Date (YYYY-MM-DD)'),
      EntityField('category', 'Category'),
      EntityField('excerpt', 'Excerpt', maxLines: 2, limit: 150),
      EntityField('body', 'Body (blank line = new paragraph)', maxLines: 8),
      EntityField('image_url', 'Image', kind: EntityKind.image),
    ],
    subtitle: _articleSubtitle,
    order: 'date',
  ),
  SiteContentKind(
    'events',
    'event',
    const [
      EntityField('title', 'Title'),
      EntityField('slug', 'Slug (website address)'),
      EntityField('start_date', 'Start date (YYYY-MM-DD)'),
      EntityField('end_date', 'End date (YYYY-MM-DD)'),
      EntityField('start_time', 'Start time (HH:MM)'),
      EntityField('end_time', 'End time (HH:MM)'),
      EntityField('location', 'Location'),
      EntityField('type', 'Type'),
      EntityField('format', 'Format'),
      EntityField('modality', 'Modality'),
      EntityField('language', 'Language'),
      EntityField('cost', 'Cost'),
      EntityField('registration_url', 'Registration URL'),
      EntityField('external_link', 'External link'),
      EntityField('about', 'About', maxLines: 5),
      EntityField('cover_image_url', 'Cover image', kind: EntityKind.image),
    ],
    subtitle: _eventSubtitle,
    order: 'start_date',
  ),
];

String? _articleSubtitle(Map<String, dynamic> r) => r['date'] as String?;
String? _eventSubtitle(Map<String, dynamic> r) => r['start_date'] as String?;

/// Admin → Website: funders, articles and events the researchers' website shows.
/// Articles and events go to Sanity only when Published is on.
class SiteContentPanel extends StatefulWidget {
  const SiteContentPanel({super.key});

  @override
  State<SiteContentPanel> createState() => _SiteContentPanelState();
}

class _SiteContentPanelState extends State<SiteContentPanel> {
  int _kind = 0;
  late Future<List<Map<String, dynamic>>> _rows = _load();

  SiteContentKind get _k => siteContentKinds[_kind];

  Future<List<Map<String, dynamic>>> _load() =>
      fetchSiteRows(_k.table, order: _k.order);

  void _refresh() => setState(() => _rows = _load());

  Future<void> _edit(Map<String, dynamic>? row) async {
    final k = _k;
    if (k.table == 'articles') {
      final saved = await showNewsWizard(context, article: row);
      if (saved == true && mounted) _refresh();
      return;
    }
    final hasSlug = k.fields.any((f) => f.key == 'slug');
    final saved = await showEntityEditor(
      context,
      title: k.label,
      entity: row,
      fields: k.fields,
      requiredKey: 'title',
      pickImage: pickAndUploadSiteImage,
      create: (data) => createSiteRow(k.table, _prepare(data, hasSlug)),
      update: (id, data) => updateSiteRow(k.table, id, _prepare(data, hasSlug)),
    );
    if (saved) _refresh();
  }

  // A blank slug is derived from the title; a blank article date keeps the
  // column's value (it is NOT NULL). `published` is the list toggle, not a field here.
  Map<String, dynamic> _prepare(Map<String, dynamic> data, bool hasSlug) => {
    for (final e in data.entries)
      if (!(e.key == 'date' && e.value == null)) e.key: e.value,
    if (hasSlug && data['slug'] == null) 'slug': slugify('${data['title']}'),
  };

  Future<void> _togglePublished(Map<String, dynamic> row, bool value) async {
    try {
      await updateSiteRow(_k.table, row['id'] as String, {'published': value});
      _refresh();
    } catch (error) {
      if (mounted) showSnack(context, '$error');
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this ${_k.label}?'),
        content: Text(
          '"${row['title']}" is removed from the portal. A copy already in Sanity stays until removed there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteSiteRow(_k.table, row['id'] as String);
      _refresh();
    } catch (error) {
      if (mounted) showSnack(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));
    return Panel(
      title: 'Website content',
      trailing: FilledButton(
        onPressed: () => _edit(null),
        child: Text(
          _k.table == 'articles' ? 'New news item (wizard)' : 'Add ${_k.label}',
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < siteContentKinds.length; i++)
                  ButtonSegment(
                    value: i,
                    label: Text(
                      siteContentKinds[i].table[0].toUpperCase() +
                          siteContentKinds[i].table.substring(1),
                      softWrap: false,
                    ),
                  ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _rows = _load();
              }),
            ),
            const SizedBox(height: 8),
            if (_k.table == 'articles' && canPublishNews())
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      if (!downloadBytes(
                        'news-template.xlsx',
                        buildNewsTemplate(),
                        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      )) {
                        showSnack(
                          context,
                          'Downloads are available in the web portal.',
                        );
                      }
                    },
                    child: const Text('Download template'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final imported = await showNewsImport(context);
                      if (imported == true && mounted) _refresh();
                    },
                    child: const Text('Import filled template'),
                  ),
                ],
              ),
            if (_k.table == 'events')
              TextButton(
                onPressed: () async {
                  try {
                    final counts = await runSanityPush(types: ['events']);
                    if (context.mounted) {
                      showSnack(
                        context,
                        'Pushed ${counts['events'] ?? 0} published event(s) to Sanity.',
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showSnack(context, 'Sanity push failed: $error');
                    }
                  }
                },
                child: const Text('Push published events to Sanity'),
              ),
            FutureBuilder(
              future: _rows,
              builder: (context, snap) {
                if (snap.hasError) return Text('${snap.error}');
                if (!snap.hasData) return const LinearProgressIndicator();
                final rows = snap.data!;
                if (rows.isEmpty) return Text('No ${_k.table} yet.');
                return Column(
                  children: [
                    for (final r in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${r['title']}'),
                        subtitle: Text(_k.subtitle?.call(r) ?? ''),
                        onTap: () => _edit(r),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (r.containsKey('published'))
                              Switch(
                                value: r['published'] == true,
                                onChanged: (v) => _togglePublished(r, v),
                              ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(r),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
