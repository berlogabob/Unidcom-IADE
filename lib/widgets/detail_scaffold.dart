import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared building blocks for the entity detail pages (labs, clusters,
/// objectives). Keeps those three files thin instead of copy-pasting the
/// header card, section headers and a generic editor into each.

/// Centered, width-capped scrolling column — the standard detail layout.
class DetailBody extends StatelessWidget {
  const DetailBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    );
  }
}

class EntityHeaderCard extends StatelessWidget {
  const EntityHeaderCard({
    super.key,
    this.code,
    required this.title,
    this.subtitle,
    this.body,
    this.chips = const [],
    this.onEdit,
  });

  final String? code;
  final String title;
  final String? subtitle;
  final String? body;
  final List<Widget> chips;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = subtitle?.trim() ?? '';
    final bodyText = body?.trim() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (code != null) ...[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      code!,
                      style: TextStyle(
                        fontSize: code!.length > 3 ? 10 : 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.headlineSmall),
                      if (sub.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            sub,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
            if (bodyText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(bodyText),
            ],
            if (onEdit != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget sectionHeader(
  BuildContext context,
  String text,
  VoidCallback? onAdd,
  String addLabel,
) {
  return Row(
    children: [
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (onAdd != null)
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
    ],
  );
}

Widget mutedText(BuildContext context, String text) => Text(
  text,
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
);

/// Pulls the embedded child rows out of a PostgREST join list
/// (e.g. embedded(lab, 'lab_objectives', 'objectives')).
List<Map<String, dynamic>> embedded(
  Map<String, dynamic> row,
  String join,
  String embed,
) {
  return (row[join] as List<dynamic>? ?? [])
      .map((e) => (e as Map<String, dynamic>)[embed] as Map<String, dynamic>?)
      .whereType<Map<String, dynamic>>()
      .toList();
}

/// A titled section of deletable chips that navigate to detail pages.
Widget linkChipsSection(
  BuildContext context, {
  required String title,
  required List<Map<String, dynamic>> items,
  required String basePath,
  required bool admin,
  VoidCallback? onAdd,
  Future<void> Function(String id)? onRemove,
}) {
  if (items.isEmpty && !admin) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionHeader(context, title, admin ? onAdd : null, 'Add'),
      const SizedBox(height: 8),
      if (items.isEmpty)
        mutedText(context, 'None linked')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              InputChip(
                label: Tooltip(
                  message: item['name'] as String? ?? '',
                  child: Text(
                    item['code'] as String? ?? item['name'] as String? ?? '—',
                  ),
                ),
                onPressed: () => context.go('$basePath/${item['id']}'),
                onDeleted: admin && onRemove != null
                    ? () => onRemove(item['id'] as String)
                    : null,
              ),
          ],
        ),
    ],
  );
}

class EntityField {
  const EntityField(this.key, this.label, {this.maxLines = 1});

  final String key;
  final String label;
  final int maxLines;
}

/// Generic add/edit dialog for a flat entity (labs, clusters, objectives).
/// Requires a non-empty 'name'. Returns true when saved.
Future<bool> showEntityEditor(
  BuildContext context, {
  required String title,
  required Map<String, dynamic>? entity,
  required List<EntityField> fields,
  required Future<String> Function(Map<String, dynamic>) create,
  required Future<void> Function(String id, Map<String, dynamic>) update,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => _EntityEditDialog(
          title: title,
          entity: entity,
          fields: fields,
          create: create,
          update: update,
        ),
      ) ??
      false;
}

class _EntityEditDialog extends StatefulWidget {
  const _EntityEditDialog({
    required this.title,
    required this.entity,
    required this.fields,
    required this.create,
    required this.update,
  });

  final String title;
  final Map<String, dynamic>? entity;
  final List<EntityField> fields;
  final Future<String> Function(Map<String, dynamic>) create;
  final Future<void> Function(String id, Map<String, dynamic>) update;

  @override
  State<_EntityEditDialog> createState() => _EntityEditDialogState();
}

class _EntityEditDialogState extends State<_EntityEditDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(
        text: widget.entity?[f.key]?.toString() ?? '',
      ),
  };
  bool _saving = false;

  bool get _creating => widget.entity?['id'] == null;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controllers['name']?.text.trim() ?? '';
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        for (final f in widget.fields)
          f.key: _controllers[f.key]!.text.trim().isEmpty
              ? null
              : _controllers[f.key]!.text.trim(),
      };
      if (_creating) {
        await widget.create(data);
      } else {
        await widget.update(widget.entity!['id'] as String, data);
      }
      if (mounted) Navigator.of(context).pop(true);
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
    return AlertDialog(
      title: Text(_creating ? 'Add ${widget.title}' : 'Edit ${widget.title}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _controllers[f.key],
                    maxLines: f.maxLines,
                    decoration: InputDecoration(
                      labelText: f.label,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
