import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/news_taxonomy.dart';
import '../data/news_template.dart';
import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

// Add a publications editor role here when that role is available.
bool canPublishNews() => isAdmin;

Future<void> saveNews(Map<String, dynamic> fields, String? id) async {
  if (!canPublishNews()) throw StateError('Admin access required');
  if (id == null) {
    await createSiteRow('articles', fields);
  } else {
    await updateSiteRow('articles', id, fields);
  }
}

Future<void> pushNews() async {
  try {
    await runSanityPush(types: ['articles']);
  } catch (_) {
    // Publishing succeeds even if the best-effort bridge is unavailable.
  }
}

Future<bool?> showNewsWizard(
  BuildContext context, {
  Map<String, dynamic>? article,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => Dialog(
    child: SizedBox(
      width: 760,
      height: 720,
      child: NewsWizard(article: article),
    ),
  ),
);

class NewsWizard extends StatefulWidget {
  const NewsWizard({
    super.key,
    this.article,
    this.canEdit = canPublishNews,
    this.loadSlugs = fetchArticleSlugs,
    this.save = saveNews,
    this.push = pushNews,
    this.pickImage = pickAndUploadSiteImage,
  });

  final Map<String, dynamic>? article;
  final bool Function() canEdit;
  final Future<Set<String>> Function() loadSlugs;
  final Future<void> Function(Map<String, dynamic>, String?) save;
  final Future<void> Function() push;
  final Future<String?> Function() pickImage;

  @override
  State<NewsWizard> createState() => _NewsWizardState();
}

class _NewsWizardState extends State<NewsWizard> {
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _excerpt = TextEditingController();
  final _body = TextEditingController();
  String? _type;
  String _precision = 'day';
  final _areas = <String>{};
  final _labs = <String>{};
  final _members = <String>{};
  String? _image;
  Set<String>? _slugs;
  String? _error;
  int _step = 0;
  bool _busy = false;
  bool _saved = false;
  bool _published = false;

  @override
  void initState() {
    super.initState();
    final row = widget.article;
    if (row != null) {
      _title.text = row['title'] as String? ?? '';
      _precision = row['date_precision'] as String? ?? 'day';
      final date = '${row['date'] ?? ''}';
      _date.text = date.length >= 10
          ? date.substring(
              0,
              _precision == 'year'
                  ? 4
                  : _precision == 'month'
                  ? 7
                  : 10,
            )
          : date;
      _excerpt.text = row['excerpt'] as String? ?? '';
      _body.text = row['body'] as String? ?? '';
      final type = row['news_type'] ?? row['category'];
      _type = newsTypes.contains(type) ? type as String : 'Unclassified';
      _image = row['image_url'] as String?;
      _areas.addAll(List<String>.from(row['scientific_areas'] ?? []));
      _labs.addAll(List<String>.from(row['lab'] ?? []));
      _members.addAll(List<String>.from(row['member_types'] ?? []));
    }
    for (final c in [_title, _date, _excerpt, _body]) {
      c.addListener(_changed);
    }
    if (widget.canEdit()) _load();
  }

  void _changed() => setState(() {});

  Future<void> _load() async {
    try {
      final slugs = await widget.loadSlugs();
      if (mounted) {
        setState(() {
          _slugs = slugs;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _date, _excerpt, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _normalizedDate {
    final raw = _date.text.trim();
    final pattern = switch (_precision) {
      'year' => r'^[1-9][0-9]{3}$',
      'month' => r'^[1-9][0-9]{3}-[0-9]{2}$',
      _ => r'^[1-9][0-9]{3}-[0-9]{2}-[0-9]{2}$',
    };
    if (!RegExp(pattern).hasMatch(raw)) return null;
    final full =
        '$raw${_precision == 'year'
            ? '-01-01'
            : _precision == 'month'
            ? '-01'
            : ''}';
    final date = DateTime.tryParse(full);
    return date != null && date.toIso8601String().startsWith(full)
        ? full
        : null;
  }

  String _slug(Set<String> slugs) {
    final existing = widget.article?['slug'] as String?;
    if (existing != null) return existing;
    return newsSlug(_title.text.trim(), {...slugs});
  }

  bool _valid(int step) => switch (step) {
    0 => _type != null,
    1 => _title.text.trim().isNotEmpty && _normalizedDate != null,
    2 => _excerpt.text.runes.length <= 150,
    _ => _valid(0) && _valid(1) && _valid(2) && _slugs != null,
  };

  Future<void> _save(bool published) async {
    if (_busy || !_valid(3) || !widget.canEdit()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Refresh at the write boundary; a database uniqueness constraint handles races.
      final slugs = await widget.loadSlugs();
      final slug = _slug(slugs);
      await widget.save({
        'title': _title.text.trim(),
        'date': _normalizedDate,
        'year': int.parse(_normalizedDate!.substring(0, 4)),
        'date_precision': _precision,
        'news_type': _type,
        'scientific_areas': _areas.toList(),
        'lab': _labs.toList(),
        'member_types': _members.toList(),
        'excerpt': _excerpt.text.trim(),
        'body': _body.text.trim(),
        'image_url': _image,
        'slug': slug,
        'published': published,
      }, widget.article?['id'] as String?);
      if (published) {
        try {
          await widget.push();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _saved = true;
          _published = published;
          _slugs = slugs;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _choices(String label, List<String> choices, Set<String> selected) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Wrap(
            spacing: 8,
            children: [
              for (final value in choices)
                FilterChip(
                  label: Text(value),
                  selected: selected.contains(value),
                  onSelected: (on) => setState(() {
                    on ? selected.add(value) : selected.remove(value);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      );

  Widget _content(int step) => switch (step) {
    0 => RadioGroup<String>(
      groupValue: _type,
      onChanged: (v) => setState(() => _type = v),
      child: Column(
        children: [
          for (final type in newsTypes)
            RadioListTile<String>(value: type, title: Text(type)),
          if (_type == 'Unclassified')
            const Text(
              'Unclassified: choose a type if you can. You can still continue.',
            ),
        ],
      ),
    ),
    1 => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        editField(_title, 'Title'),
        DropdownButtonFormField<String>(
          initialValue: _precision,
          decoration: const InputDecoration(labelText: 'Date precision'),
          items: [
            for (final p in ['year', 'month', 'day'])
              DropdownMenuItem(value: p, child: Text(p)),
          ],
          onChanged: (v) => setState(() => _precision = v!),
        ),
        editField(
          _date,
          'Date (${_precision == 'year'
              ? 'YYYY'
              : _precision == 'month'
              ? 'YYYY-MM'
              : 'YYYY-MM-DD'})',
        ),
        if (_date.text.isNotEmpty && _normalizedDate == null)
          const Text('Enter a valid date at the selected precision.'),
        _choices('Scientific area', newsScientificAreas, _areas),
        _choices('Labs', newsLabs, _labs),
        _choices('Member types', newsMemberTypes, _members),
      ],
    ),
    2 => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        editField(_excerpt, 'Excerpt', maxLines: 2),
        Text(
          '${_excerpt.text.runes.length}/150',
          key: const ValueKey('excerpt-counter'),
        ),
        if (!_valid(2)) const Text('Excerpt must be 150 characters or fewer.'),
        editField(_body, 'Body (blank line = new paragraph)', maxLines: 8),
        if (_image != null) ...[
          Image.network(
            _image!,
            height: 120,
            errorBuilder: (_, e, s) => const Text('Image preview unavailable'),
          ),
          Text(_image!),
          TextButton(
            onPressed: () => setState(() => _image = null),
            child: const Text('Remove image'),
          ),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('Upload image'),
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    final image = await widget.pickImage();
                    if (mounted && image != null) {
                      setState(() => _image = image);
                    }
                  } catch (e) {
                    if (mounted) showSnack(context, '$e');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
      ],
    ),
    _ => Panel(
      title: 'Ready to publish',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title.text.trim()),
          Text('Type: $_type'),
          Text('Date: ${_date.text.trim()} ($_precision)'),
          Text('Scientific area: ${_areas.join(', ')}'),
          Text('Labs: ${_labs.join(', ')}'),
          Text('Member types: ${_members.join(', ')}'),
          Text('Excerpt: ${_excerpt.text.trim()}'),
          Text('Body: ${_body.text.trim()}'),
          Text('Image: ${_image ?? 'None'}'),
          if (_slugs != null) ...[
            Text('Slug: ${_slug(_slugs!)}'),
            Text(
              widget.article == null
                  ? 'Unique among current article slugs; checked again when saving.'
                  : 'Existing website address retained.',
            ),
          ],
          Text(
            _valid(3)
                ? 'Validation: ready to save.'
                : 'Validation: check the required fields.',
          ),
          if (_type == 'Unclassified')
            const Text('Warning: Unclassified type.'),
          if (_labs.isEmpty) const Text('Warning: missing lab.'),
        ],
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.canEdit()) {
      return const Center(child: Text('Admin access required'));
    }
    if (_saved) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _published
                  ? 'News published. The website updates in a few minutes.'
                  : 'Draft saved.',
            ),
            if (_published)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Check website'),
                onPressed: () => launchUrl(
                  Uri.parse('https://berlogabob.github.io/unidcom-site/'),
                  webOnlyWindowName: '_blank',
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
    return PopScope(
      canPop: !_busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.article == null ? 'Publish news' : 'Edit news',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          if (_slugs == null && _error == null) const LinearProgressIndicator(),
          if (_slugs == null && _error != null)
            TextButton(onPressed: _load, child: const Text('Retry')),
          Expanded(
            child: Stepper(
              currentStep: _step,
              controlsBuilder: (context, details) => details.stepIndex != _step
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_step == 3) ...[
                            FilledButton(
                              onPressed: !_busy && _valid(3)
                                  ? () => _save(false)
                                  : null,
                              child: const Text('Save draft'),
                            ),
                            FilledButton(
                              onPressed: !_busy && _valid(3)
                                  ? () => _save(true)
                                  : null,
                              child: const Text('Publish'),
                            ),
                          ] else
                            FilledButton(
                              onPressed: !_busy && _valid(_step)
                                  ? () => setState(() => _step++)
                                  : null,
                              child: const Text('Continue'),
                            ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    if (_step == 0) {
                                      Navigator.of(context).pop(false);
                                    } else {
                                      setState(() => _step--);
                                    }
                                  },
                            child: const Text('Back'),
                          ),
                          if (_busy) const CircularProgressIndicator(),
                        ],
                      ),
                    ),
              steps: [
                for (var i = 0; i < 4; i++)
                  Step(
                    title: Text(
                      ['Type', 'Details', 'Text & image', 'Review'][i],
                    ),
                    content: _content(i),
                    isActive: i <= _step,
                    state: i < _step ? StepState.complete : StepState.indexed,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
