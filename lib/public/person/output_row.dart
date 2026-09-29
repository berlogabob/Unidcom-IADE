import 'package:flutter/material.dart';

import '../../data/status_labels.dart';
import '../../widgets/output_row.dart';
import '../../widgets/panels.dart';

class PersonOutputRow extends StatelessWidget {
  const PersonOutputRow({
    super.key,
    required this.author,
    required this.isFeatured,
    required this.onTap,
    this.onToggle,
    this.onEdit,
    this.showStates = false,
    this.featurable = true,
  });

  final Map<String, dynamic> author;
  final bool isFeatured;
  final ValueChanged<String> onTap;
  final ValueChanged<String>? onToggle;
  final ValueChanged<String>? onEdit;
  final bool showStates;
  final bool featurable;

  @override
  Widget build(BuildContext context) {
    final output = author['outputs'] as Map<String, dynamic>?;
    if (output == null) return const SizedBox.shrink();
    final id = output['id'] as String;
    final subtype = output['subtype'] as String?;
    final doi = output['doi'] as String?;
    final type = [output['type'], subtype]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final detail = [
      if ((author['role'] as String?)?.isNotEmpty == true) author['role'],
      if (doi?.trim().isNotEmpty == true) 'DOI $doi',
    ].join(' · ');
    return OutputRow(
      title: output['title'] as String? ?? 'Untitled',
      year: output['reporting_year'] as int?,
      type: type.isEmpty ? null : type,
      detail: detail.isEmpty ? null : detail,
      status: output['approval_status'] == 'approved'
          ? null
          : output['approval_status'] as String?,
      rejectionReason: output['approval_status'] == 'rejected'
          ? output['rejection_reason'] as String?
          : null,
      issueCodes: (output['issue_codes'] as List<dynamic>?)?.cast<String>(),
      errorCount: output['error_count'] as int? ?? 0,
      warningCount: output['warning_count'] as int? ?? 0,
      showNoIssues: showStates,
      extraPills: showStates
          ? [
              (
                output['source'] == 'orcid' ? 'On ORCID' : 'Not on ORCID',
                output['source'] == 'orcid' ? PillTone.teal : PillTone.grey,
              ),
              (
                'Website · ${websiteLabel(output['website_status'] as String?)}',
                output['website_status'] == 'published'
                    ? PillTone.teal
                    : PillTone.grey,
              ),
            ]
          : const [],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit output',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => onEdit!(id),
            ),
          if (onToggle != null && featurable)
            IconButton(
              // The tooltip doubles as the UI-test handle: it reaches the web
              // semantics tree as text, and encodes which state we're in.
              tooltip: isFeatured ? 'Remove highlight' : 'Highlight on profile',
              icon: Icon(isFeatured ? Icons.star : Icons.star_border, size: 20),
              onPressed: () => onToggle!(id),
            )
          else if (isFeatured)
            const Tooltip(
              message: 'Highlighted',
              child: Icon(Icons.star, size: 20),
            ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
      onTap: () => onTap(id),
    );
  }
}
