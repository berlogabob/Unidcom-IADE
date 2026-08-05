import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import 'panels.dart';

/// Shared building blocks for the entity detail pages. Keeps them thin
/// instead of copy-pasting the header card, section headers, async
/// preamble and a generic editor into each.

/// FutureBuilder with the standard spinner/error preamble.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.future, required this.builder});

  final Future<T> future;
  final Widget Function(BuildContext, T) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.teal),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error.toString(),
              style: const TextStyle(color: AppColors.red),
            ),
          );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// Snackbar helper safe to call after awaits.
void showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

PillTone _statusPillTone(String label) {
  final value = label.toLowerCase();
  if (value.contains('rejected') ||
      value.contains('inactive') ||
      value.contains('error')) {
    return PillTone.red;
  }
  if (value.contains('approved') ||
      value.contains('active') ||
      value.contains('validated')) {
    return PillTone.teal;
  }
  if (value.contains('pending') ||
      value.contains('a_confirmar') ||
      value.contains('awaiting')) {
    return PillTone.amber;
  }
  return PillTone.grey;
}

StatusPill _statusPill(String label) =>
    StatusPill(label, tone: _statusPillTone(label));

/// Compact chips for the non-empty values — feeds [EntityHeaderCard.chips].
List<Widget> statusChips(Iterable<Object?> values) {
  assert(_statusPillTone('inactive') == PillTone.red);
  return [
    for (final v in values)
      if (v != null && v.toString().trim().isNotEmpty)
        _statusPill(v.toString()),
  ];
}

/// Titled pill wrap of collaborations.
Widget collaborationChips(
  BuildContext context,
  List<Map<String, dynamic>> items, {
  double bottomPadding = 8,
}) {
  if (items.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: EdgeInsets.only(bottom: bottomPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(context, 'Collaborations'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in items) _statusPill(c['name'] as String? ?? '—'),
          ],
        ),
      ],
    ),
  );
}

/// Year a project started, parsed from its ISO start_date.
int? projectStartYear(Map<String, dynamic> project) =>
    int.tryParse((project['start_date'] as String? ?? '').split('-').first);

/// Standard project row: title, status, chevron, navigates to the project.
class ProjectTile extends StatelessWidget {
  const ProjectTile({super.key, required this.project});

  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(project['title'] as String? ?? 'Untitled'),
        subtitle: Text(project['status'] as String? ?? ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/projects/${project['id']}'),
      ),
    );
  }
}

/// Round avatar showing a short entity code (lab/cluster/objective).
class CodeAvatar extends StatelessWidget {
  const CodeAvatar({super.key, required this.code, this.radius = 24});

  final String code;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        code,
        style: TextStyle(
          fontSize: code.length > 3 ? 10 : 13,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Standard editor-dialog text field with bottom spacing.
Widget editField(
  TextEditingController controller,
  String label, {
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
      ),
    ),
  );
}

/// Standard editor-dialog dropdown with bottom spacing.
Widget editDropdown(
  String label,
  String value,
  List<String> values,
  ValueChanged<String?> onChanged,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : values.first,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
    ),
  );
}

/// Standard Cancel/Save actions for editor dialogs.
List<Widget> editorActions(
  BuildContext context, {
  required bool saving,
  required VoidCallback onSave,
}) => [
  TextButton(
    onPressed: saving ? null : () => Navigator.of(context).pop(false),
    child: const Text('Cancel'),
  ),
  FilledButton(
    onPressed: saving ? null : onSave,
    child: Text(saving ? 'Saving...' : 'Save'),
  ),
];

/// Centered, width-capped scrolling column — the standard detail layout.
class DetailBody extends StatelessWidget {
  const DetailBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        ),
      ),
    );
  }
}

class EntityHeaderCard extends StatelessWidget {
  const EntityHeaderCard({
    super.key,
    this.code,
    this.leading,
    required this.title,
    this.subtitle,
    this.body,
    this.chips = const [],
    this.extra = const [],
    this.actions = const [],
    this.onEdit,
  });

  final String? code;

  /// Custom leading widget (e.g. a photo avatar); overrides [code].
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? body;
  final List<Widget> chips;

  /// Extra widgets below the body (references, DOI rows, notes…).
  final List<Widget> extra;

  /// Footer action buttons; rendered alongside the [onEdit] button.
  final List<Widget> actions;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle?.trim() ?? '';
    final bodyText = body?.trim() ?? '';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 16),
              ] else if (code != null) ...[
                CodeAvatar(code: code!),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          sub,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
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
          for (final widget in extra) ...[const SizedBox(height: 8), widget],
          if (onEdit != null || actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onEdit != null)
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ...actions,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Widget sectionHeader(
  BuildContext context,
  String text, {
  VoidCallback? onAdd,
  String addLabel = 'Add',
}) {
  return Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
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
  style: Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
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
      sectionHeader(context, title, onAdd: admin ? onAdd : null),
      const SizedBox(height: 8),
      if (items.isEmpty)
        mutedText(context, 'None linked')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              Builder(
                builder: (context) {
                  final label =
                      item['code'] as String? ?? item['name'] as String? ?? '—';
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => context.go('$basePath/${item['id']}'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const StadiumBorder(),
                        ),
                        child: Tooltip(
                          message: item['name'] as String? ?? '',
                          child: _statusPill(label),
                        ),
                      ),
                      if (admin && onRemove != null)
                        IconButton(
                          onPressed: () => onRemove(item['id'] as String),
                          icon: const Icon(Icons.close, size: 16),
                          color: AppColors.textMuted,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                        ),
                    ],
                  );
                },
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
      showSnack(context, 'Name is required');
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
      showSnack(context, error.toString());
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
                editField(_controllers[f.key]!, f.label, maxLines: f.maxLines),
            ],
          ),
        ),
      ),
      actions: editorActions(context, saving: _saving, onSave: _save),
    );
  }
}
