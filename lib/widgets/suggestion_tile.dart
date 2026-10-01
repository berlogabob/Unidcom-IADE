import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _fieldLabels = {
  'bio': 'Bio',
  'legal_name': 'Legal name',
  'preferred_name': 'Preferred name',
  'orcid': 'ORCID',
  'ciencia_id': 'Ciência ID',
  'email': 'Email',
  'photo_url': 'Photo',
  'title': 'Title',
  'doi': 'DOI',
};

String suggestionFieldLabel(Object? field) => _fieldLabels[field] ?? '$field';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String dayLabel(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Who proposed it and when: a researcher's edit is not a "100%" guess, and
/// an ORCID/Crossref match is not a human request.
String suggestionOrigin(Map<String, dynamic> suggestion) {
  final source = suggestion['source'] as String?;
  final created = DateTime.tryParse('${suggestion['created_at']}')?.toLocal();
  final confidence = num.tryParse('${suggestion['confidence']}');
  final who = switch (source) {
    'researcher' => 'Proposed by the researcher',
    'orcid' => 'Found on ORCID',
    'crossref' => 'Found on Crossref',
    _ => 'From ${source ?? 'unknown source'}',
  };
  return [
    who,
    if (source != 'researcher' && confidence != null)
      '${(confidence * 100).round()}% match',
    if (created != null) dayLabel(created),
  ].join(' · ');
}

/// Enrichment-suggestion row: field, origin ("Found on ORCID · 40% match ·
/// 1 Oct 2026"), current and proposed value, with
/// Accept/Reject actions. Shared by the review queue and the person page
/// (which hides the redundant subject title via [showTitle]).
class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onReject,
    this.showTitle = true,
    this.onOpenClash,
    this.clashTitle,
  });

  final Map<String, dynamic> suggestion;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool showTitle;

  /// Set for a `duplicate_of` suggestion: the found DOI already belongs to
  /// another output, so there is nothing to accept — the admin goes and merges.
  final VoidCallback? onOpenClash;
  final String? clashTitle;

  @override
  Widget build(BuildContext context) {
    final current = suggestion['current_value'] as String?;
    final value = suggestion['suggested_value'] as String? ?? '';
    final confidence = suggestion['confidence'];
    final confidenceText = confidence == null
        ? ''
        : ' · ${(num.parse(confidence.toString()) * 100).round()}%';
    final isClash = suggestion['field'] == 'duplicate_of';
    final Widget detail = isClash
        ? Text(
            'DOI already belongs to: ${clashTitle ?? value}\n'
            'possible duplicate — merge instead$confidenceText',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestionOrigin(suggestion),
                style: const TextStyle(color: AppColors.textMuted),
              ),
              Text(
                'Now: ${current?.trim().isNotEmpty == true ? current : 'empty'}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Proposed: $value',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
    final field = isClash ? null : suggestionFieldLabel(suggestion['field']);

    return ListTile(
      title: showTitle
          ? Text(
              [
                suggestion['subject_name'] as String? ?? 'Missing subject',
                ?field,
              ].join(' · '),
            )
          : (field == null ? detail : Text(field)),
      subtitle: showTitle || field != null ? detail : null,
      isThreeLine: showTitle || field != null,
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: onReject,
            child: Text(isClash ? 'Dismiss' : 'Reject'),
          ),
          if (isClash)
            if (onOpenClash != null)
              FilledButton(
                onPressed: onOpenClash,
                child: const Text('Open duplicate'),
              )
            else
              const SizedBox.shrink()
          else
            FilledButton(onPressed: onAccept, child: const Text('Accept')),
        ],
      ),
    );
  }
}
