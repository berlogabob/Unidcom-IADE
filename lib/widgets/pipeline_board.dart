import 'package:flutter/material.dart';

Map<String, List<Map<String, dynamic>>> pipelineColumns(
  List<Map<String, dynamic>> people,
) {
  final columns = <String, List<Map<String, dynamic>>>{
    'To validate': [],
    'Submitted': [],
    'Approved, not published': [],
    'Published': [],
  };

  for (final person in people) {
    final status = person['profile_status'];
    final published = person['public_visibility'] == true;
    final column = published
        ? 'Published'
        : switch (status) {
            'to_validate' || 'draft' => 'To validate',
            'pending_review' => 'Submitted',
            'approved' => 'Approved, not published',
            _ => null,
          };
    if (column != null) columns[column]!.add(person);
  }
  return columns;
}

/// Rui 25 Sep (A1·8): stage pipeline; Publish to website is separate from Approve.
class PipelineBoard extends StatelessWidget {
  const PipelineBoard({
    super.key,
    required this.people,
    required this.onApprove,
    required this.onPublish,
    required this.onUnpublish,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> people;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onPublish;
  final ValueChanged<String> onUnpublish;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final columns = pipelineColumns(people);
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = [
          for (final entry in columns.entries) _column(entry.key, entry.value),
        ];
        return constraints.maxWidth >= 900
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final child in children) Expanded(child: child)],
              )
            : Column(children: children);
      },
    );
  }

  Widget _column(String name, List<Map<String, dynamic>> people) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$name · ${people.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final person in people) _personCard(name, person),
        ],
      ),
    );
  }

  Widget _personCard(String column, Map<String, dynamic> person) {
    final id = person['id'] as String;
    final action = switch (column) {
      'Submitted' => TextButton(
          onPressed: () => onApprove(id),
          child: const Text('Approve'),
        ),
      'Approved, not published' => FilledButton(
          onPressed: () => onPublish(id),
          child: const Text('Publish to website'),
        ),
      'Published' => TextButton(
          onPressed: () => onUnpublish(id),
          child: const Text('Unpublish'),
        ),
      _ => null,
    };

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(person['preferred_name'] as String? ?? 'Unnamed'),
            subtitle: column == 'To validate'
                ? const Text('Waiting for the researcher')
                : null,
            onTap: () => onOpen(id),
          ),
          if (action != null) Align(alignment: Alignment.centerLeft, child: action),
        ],
      ),
    );
  }
}
