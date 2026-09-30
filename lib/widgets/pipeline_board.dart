import 'package:flutter/material.dart';

import 'info_tip.dart';

Map<String, List<Map<String, dynamic>>> pipelineColumns(
  List<Map<String, dynamic>> people,
) {
  final columns = <String, List<Map<String, dynamic>>>{
    'Draft': [],
    'Submitted': [],
    'Under review': [],
    'Approved, not published': [],
    'Published': [],
  };

  for (final person in people) {
    final status = person['profile_status'];
    final published = person['public_visibility'] == true;
    // By review state first: an imported profile already on the site is
    // still "Draft" until its researcher submits (Rui 25 Sep).
    final column = switch (status) {
      'to_validate' || 'draft' => 'Draft',
      'pending_review' => 'Submitted',
      'under_review' => 'Under review',
      'approved' => published ? 'Published' : 'Approved, not published',
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
    required this.onStartReview,
    required this.onApprove,
    required this.onRequestChanges,
    required this.onReject,
    required this.onPublish,
    required this.onUnpublish,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> people;
  final ValueChanged<String> onStartReview;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onRequestChanges;
  final ValueChanged<String> onReject;
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
                children: [
                  for (final child in children) Expanded(child: child),
                ],
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
          Text(
            '$name · ${people.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // ponytail: first 10 per column; a search/paging UI if columns stay long.
          for (final person in people.take(10)) _personCard(name, person),
          if (people.length > 10)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('+${people.length - 10} more'),
            ),
        ],
      ),
    );
  }

  Widget _personCard(String column, Map<String, dynamic> person) {
    final id = person['id'] as String;
    final action = switch (column) {
      'Submitted' => Wrap(
        spacing: 4,
        children: [
          WithInfo(
            info: 'Moves the profile to Under review, so the researcher sees UNIDCOM is on it.',
            child: TextButton(
              onPressed: () => onStartReview(id),
              child: const Text('Start review'),
            ),
          ),
          _approveAction(id),
          _requestChangesAction(id),
          _rejectAction(id),
        ],
      ),
      'Under review' => Wrap(
        spacing: 4,
        children: [
          _approveAction(id),
          _requestChangesAction(id),
          _rejectAction(id),
        ],
      ),
      'Approved, not published' => WithInfo(
        info: 'Puts this on the UNIDCOM website at the next sync.',
        child: FilledButton(
          onPressed: () => onPublish(id),
          child: const Text('Publish to website'),
        ),
      ),
      'Published' => WithInfo(
        info: 'Removes this from the website at the next sync.',
        child: TextButton(
          onPressed: () => onUnpublish(id),
          child: const Text('Unpublish'),
        ),
      ),
      _ => null,
    };

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(person['preferred_name'] as String? ?? 'Unnamed'),
            subtitle: column == 'Draft'
                ? Text(
                    person['review_note'] is String &&
                            (person['review_note'] as String).isNotEmpty
                        ? 'Changes requested: ${person['review_note']}'
                        : person['public_visibility'] == true
                        ? 'On the website (imported) · waiting for the researcher'
                        : 'Waiting for the researcher',
                  )
                : null,
            onTap: () => onOpen(id),
          ),
          if (action != null)
            Align(alignment: Alignment.centerLeft, child: action),
        ],
      ),
    );
  }

  Widget _approveAction(String id) => WithInfo(
    info: 'Confirms the profile. It does not publish it.',
    child: TextButton(
      onPressed: () => onApprove(id),
      child: const Text('Approve'),
    ),
  );

  Widget _requestChangesAction(String id) => WithInfo(
    info: 'Sends the profile back to the researcher as a draft, with your note.',
    child: TextButton(
      onPressed: () => onRequestChanges(id),
      child: const Text('Request changes'),
    ),
  );

  Widget _rejectAction(String id) => WithInfo(
    info: 'Declines this submission and its proposed changes; the researcher sees your note.',
    child: TextButton(
      onPressed: () => onReject(id),
      child: const Text('Reject'),
    ),
  );
}
