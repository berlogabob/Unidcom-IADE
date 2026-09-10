import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/enrich_client.dart';
import '../data/supabase.dart';
import '../data/taxonomy.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';
import '../widgets/taxonomy_picker.dart';

enum WizardStep { doi, type, subtype, metadata, project, review }

List<WizardStep> wizardSteps({
  required bool typeHasChildren,
  required bool hasProjects,
}) => [
  WizardStep.doi,
  WizardStep.type,
  if (typeHasChildren) WizardStep.subtype,
  WizardStep.metadata,
  if (hasProjects) WizardStep.project,
  WizardStep.review,
];

Future<bool?> showOutputWizard(
  BuildContext context, {
  Future<DoiWork?> Function(String doi) lookup = lookupDoi,
  Future<List<Map<String, dynamic>>> Function({String? doi, String? title})
      findSimilar =
      findSimilarOutputs,
  Future<List<TaxonomyNode>> Function() loadTaxonomy = fetchOutputTaxonomy,
  Future<Map<String, String>> Function() loadKinds = fetchTaxonomyKinds,
  Future<List<({String id, String title})>> Function(String personId)
      loadProjects =
      fetchMyProjects,
  Future<Map<String, dynamic>?> Function() loadPerson = fetchMyPerson,
  Future<String> Function(
        Map<String, dynamic> fields, {
        List<String> projectIds,
      })
      create =
      createMyOutput,
}) => showDialog<bool>(
  context: context,
  builder: (context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      child: SizedBox(
        width: 760,
        height: 720,
        child: OutputWizard(
          lookup: lookup,
          findSimilar: findSimilar,
          loadTaxonomy: loadTaxonomy,
          loadKinds: loadKinds,
          loadProjects: loadProjects,
          loadPerson: loadPerson,
          create: create,
        ),
      ),
    ),
  ),
);

class OutputWizard extends StatefulWidget {
  const OutputWizard({
    super.key,
    this.lookup = lookupDoi,
    this.findSimilar = findSimilarOutputs,
    this.loadTaxonomy = fetchOutputTaxonomy,
    this.loadKinds = fetchTaxonomyKinds,
    this.loadProjects = fetchMyProjects,
    this.loadPerson = fetchMyPerson,
    this.create = createMyOutput,
  });

  final Future<DoiWork?> Function(String doi) lookup;
  final Future<List<Map<String, dynamic>>> Function({
    String? doi,
    String? title,
  })
  findSimilar;
  final Future<List<TaxonomyNode>> Function() loadTaxonomy;
  final Future<Map<String, String>> Function() loadKinds;
  final Future<List<({String id, String title})>> Function(String personId)
  loadProjects;
  final Future<Map<String, dynamic>?> Function() loadPerson;
  final Future<String> Function(
    Map<String, dynamic> fields, {
    List<String> projectIds,
  })
  create;

  @override
  State<OutputWizard> createState() => _OutputWizardState();
}

class _OutputWizardState extends State<OutputWizard> {
  final _doi = TextEditingController();
  final _title = TextEditingController();
  final _year = TextEditingController();
  final _reference = TextEditingController();
  final _url = TextEditingController();
  final _status = TextEditingController();
  List<TaxonomyNode>? _roots;
  Map<String, String> _kinds = const {};
  List<({String id, String title})> _projects = const [];
  final _selectedProjects = <String>{};
  List<String> _category = const [];
  Map<String, dynamic>? _doiMatch;
  List<Map<String, dynamic>> _titleMatches = const [];
  int _current = 0;
  bool _lookingUp = false;
  bool _saving = false;
  String? _lookupMessage;
  String? _loadError;
  String? _doiType;

  @override
  void initState() {
    super.initState();
    for (final controller in [_doi, _title, _year, _reference, _url, _status]) {
      controller.addListener(_fieldChanged);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await Future.wait<Object?>([
        widget.loadTaxonomy(),
        widget.loadKinds(),
        widget.loadPerson(),
      ]);
      final person = loaded[2] as Map<String, dynamic>?;
      final projects = person == null
          ? <({String id, String title})>[]
          : await widget.loadProjects(person['id'] as String);
      if (!mounted) return;
      setState(() {
        _roots = loaded[0] as List<TaxonomyNode>;
        _kinds = loaded[1] as Map<String, String>;
        _projects = projects;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  void _fieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [_doi, _title, _year, _reference, _url, _status]) {
      controller
        ..removeListener(_fieldChanged)
        ..dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  TaxonomyNode? get _selectedRoot {
    if (_category.isEmpty) return null;
    return _roots?.where((node) => node.label == _category.first).firstOrNull;
  }

  List<WizardStep> get _steps => wizardSteps(
    typeHasChildren: _selectedRoot?.children.isNotEmpty ?? false,
    hasProjects: _projects.isNotEmpty,
  );

  bool _valid(WizardStep step) => switch (step) {
    WizardStep.doi => _doiMatch == null && !_lookingUp,
    WizardStep.type => _category.isNotEmpty,
    WizardStep.subtype => _category.length >= 2,
    WizardStep.metadata =>
      _title.text.trim().isNotEmpty &&
          RegExp(r'^\d{4}$').hasMatch(_year.text.trim()) &&
          int.tryParse(_year.text.trim()) != null,
    WizardStep.project || WizardStep.review => true,
  };

  Future<void> _lookup() async {
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
      _doiMatch = null;
      _titleMatches = const [];
    });
    try {
      final work = await widget.lookup(cleanDoi(_doi.text) ?? '');
      if (!mounted) return;
      if (work == null) {
        setState(() => _lookupMessage = 'No record found for that DOI.');
        return;
      }
      _title.text = work.title;
      _doi.text = work.doi;
      if (work.year != null) _year.text = '${work.year}';
      _reference.text = [
        work.authors.join(', '),
        work.title,
        work.containerTitle,
        if (work.year != null) '${work.year}',
      ].where((part) => part.isNotEmpty).join(' · ');
      _doiType = work.type;
      final suggested = switch (work.type) {
        'journal-article' => 'Artigos em revistas',
        'book' || 'book-chapter' => 'Livros',
        _ => null,
      };
      if (suggested != null && _roots!.any((node) => node.label == suggested)) {
        _category = [suggested];
      }
      final matches = await widget.findSimilar(
        doi: cleanDoi(_doi.text),
        title: _text(_title),
      );
      if (!mounted) return;
      setState(() {
        _doiMatch = matches.where((row) => row['match'] == 'doi').firstOrNull;
        _titleMatches = _doiMatch == null
            ? matches
                  .where(
                    (row) =>
                        row['match'] == 'title' &&
                        (row['score'] as num? ?? 0) >= 0.8,
                  )
                  .take(3)
                  .toList()
            : const [];
      });
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _openMatch() {
    final id = _doiMatch!['id'];
    final router = GoRouter.of(context);
    Navigator.of(context).pop(false);
    router.go('/outputs/$id');
  }

  void _continue() {
    if (!_valid(_steps[_current])) return;
    if (_steps[_current] == WizardStep.review) {
      _submit();
    } else {
      setState(() => _current++);
    }
  }

  void _back() {
    if (_current == 0) {
      Navigator.of(context).pop(false);
    } else {
      setState(() => _current--);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final fields = {
      'title': _text(_title),
      'doi': _text(_doi),
      'url': _text(_url),
      'full_reference': _text(_reference),
      'category_path': _category.join(categorySeparator),
      ...categoryFields(_category),
      'reporting_year': int.parse(_year.text.trim()),
      'output_status': _text(_status),
    };
    try {
      await widget.create(fields, projectIds: _selectedProjects.toList());
      if (!mounted) return;
      showSnack(context, 'Output submitted for review');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showSnack(context, error.toString());
      setState(() => _saving = false);
    }
  }

  Widget _doiStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _doi,
        decoration: const InputDecoration(
          labelText: 'DOI (or paste the doi.org link)',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _lookup(),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          FilledButton.tonal(
            onPressed: _lookingUp ? null : _lookup,
            child: Text(_lookingUp ? 'Looking up…' : 'Look up'),
          ),
          TextButton(
            onPressed: _valid(WizardStep.doi) ? _continue : null,
            child: const Text('No DOI — enter manually'),
          ),
        ],
      ),
      if (_lookupMessage != null) mutedText(context, _lookupMessage!),
      if (_doiType != null) mutedText(context, 'DOI type: $_doiType'),
      if (_doiMatch != null) ...[
        const Text('This output is already recorded'),
        TextButton(onPressed: _openMatch, child: const Text('Open it')),
      ],
      if (_titleMatches.isNotEmpty) ...[
        const Text(
          'Similar titles already recorded — continue only if this is a different work',
        ),
        for (final match in _titleMatches) Text('${match['title']}'),
      ],
    ],
  );

  Widget _typeStep() => RadioGroup<String>(
    groupValue: _category.firstOrNull,
    onChanged: (value) => setState(() => _category = [value!]),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in ['publication', 'activity']) ...[
          Text(group == 'publication' ? 'Publications' : 'Research activities'),
          for (final root in _roots!)
            if ((_kinds[root.label] ?? 'activity') == group)
              RadioListTile<String>(title: Text(root.label), value: root.label),
        ],
      ],
    ),
  );

  Widget _subtypeStep() {
    final children = _selectedRoot!.children;
    return RadioGroup<String>(
      groupValue: _category.length > 1 ? _category[1] : null,
      onChanged: (value) =>
          setState(() => _category = [_category.first, value!]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final child in children)
            RadioListTile<String>(title: Text(child.label), value: child.label),
          if (_category.length > 1 &&
              children
                      .where((node) => node.label == _category[1])
                      .firstOrNull
                      ?.children
                      .isNotEmpty ==
                  true) ...[
            const SizedBox(height: 8),
            TaxonomyPicker(
              roots: _roots!,
              value: _category,
              onChanged: (value) => setState(() => _category = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metadataStep() => Column(
    children: [
      editField(_title, 'Title'),
      editField(_year, 'Reporting year', keyboardType: TextInputType.number),
      editField(_reference, 'Full reference', maxLines: 3),
      editField(_url, 'URL'),
      editField(_status, 'Output status'),
    ],
  );

  Widget _projectStep() => Column(
    children: [
      for (final project in _projects)
        CheckboxListTile(
          title: Text(project.title),
          value: _selectedProjects.contains(project.id),
          onChanged: (selected) => setState(() {
            if (selected ?? false) {
              _selectedProjects.add(project.id);
            } else {
              _selectedProjects.remove(project.id);
            }
          }),
        ),
    ],
  );

  Widget _reviewStep() => Panel(
    title: 'Ready to submit',
    trailing: const StatusPill('Submitted', tone: PillTone.amber),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_category.join(categorySeparator)),
        Text(_title.text.trim()),
        Text(_year.text.trim()),
        if (_text(_doi) != null) Text('DOI: ${_text(_doi)}'),
        if (_text(_reference) != null) Text(_text(_reference)!),
        if (_selectedProjects.isNotEmpty)
          Text(
            'Projects: ${_projects.where((project) => _selectedProjects.contains(project.id)).map((project) => project.title).join(', ')}',
          ),
        const SizedBox(height: 12),
        mutedText(
          context,
          'Saved as Submitted; UNIDCOM reviews it before anything is published.',
        ),
      ],
    ),
  );

  Widget _content(WizardStep step) => switch (step) {
    WizardStep.doi => _doiStep(),
    WizardStep.type => _typeStep(),
    WizardStep.subtype => _subtypeStep(),
    WizardStep.metadata => _metadataStep(),
    WizardStep.project => _projectStep(),
    WizardStep.review => _reviewStep(),
  };

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) return Center(child: Text(_loadError!));
    if (_roots == null) return const Center(child: CircularProgressIndicator());
    final steps = _steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Add output',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stepper(
            key: ValueKey((
              _selectedRoot?.children.isNotEmpty ?? false,
              _projects.isNotEmpty,
            )),
            currentStep: _current,
            type: StepperType.vertical,
            onStepContinue: _valid(steps[_current]) && !_saving
                ? _continue
                : null,
            onStepCancel: _back,
            controlsBuilder: (context, details) => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(
                      steps[_current] == WizardStep.review
                          ? 'Submit for UNIDCOM review'
                          : 'Continue',
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
            steps: [
              for (final step in steps)
                Step(
                  title: Text(switch (step) {
                    WizardStep.doi => 'DOI',
                    WizardStep.type => 'Type',
                    WizardStep.subtype => 'Subtype',
                    WizardStep.metadata => 'Metadata',
                    WizardStep.project => 'Project',
                    WizardStep.review => 'Review',
                  }),
                  content: _content(step),
                  isActive: steps.indexOf(step) <= _current,
                  state: steps.indexOf(step) < _current
                      ? StepState.complete
                      : StepState.indexed,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
