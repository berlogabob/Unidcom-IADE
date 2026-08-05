import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'panels.dart';

PillTone _typeTone(String type) {
  final value = type.toLowerCase();
  if (value.contains('journal') || value.contains('article')) {
    return PillTone.teal;
  }
  if (value.contains('book') || value.contains('chapter')) {
    return PillTone.blue;
  }
  if (value.contains('conference') || value.contains('proceedings')) {
    return PillTone.purple;
  }
  return PillTone.grey;
}

PillTone? _statusTone(String? detail) {
  final status = detail?.toLowerCase();
  if (!const {
    'approved',
    'validated',
    'pending',
    'rejected',
    'pending_review',
  }.contains(status)) {
    return null;
  }
  return switch (status) {
    'approved' || 'validated' => PillTone.teal,
    'pending' => PillTone.amber,
    'rejected' => PillTone.red,
    _ => PillTone.grey,
  };
}

/// Resolves an openable link for an output: prefer an explicit url, else a DOI
/// resolver link, else null (nothing to open).
String? resolveOutputUrl(String? url, String? doi) {
  final u = url?.trim() ?? '';
  if (u.isNotEmpty) return u;
  final d = doi?.trim() ?? '';
  if (d.isNotEmpty) return 'https://doi.org/$d';
  return null;
}

class OutputRow extends StatelessWidget {
  const OutputRow({
    super.key,
    required this.title,
    this.year,
    this.type,
    this.detail,
    this.trailing,
    this.onTap,
    this.issueCodes,
    this.errorCount = 0,
    this.warningCount = 0,
  });

  final String title;
  final int? year;
  final String? type;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Data-quality issue codes from `v_output_quality` (e.g. `missing_doi`).
  /// When non-empty, a warning badge is rendered alongside [trailing].
  final List<String>? issueCodes;
  final int errorCount;
  final int warningCount;

  @override
  Widget build(BuildContext context) {
    final statusTone = _statusTone(detail);
    final meta = [
      if (year != null) year.toString(),
      if (statusTone == null && detail != null && detail!.isNotEmpty) detail!,
    ].join(' · ');

    final codes = issueCodes ?? const [];
    Widget? trailingWidget = trailing;
    if (codes.isNotEmpty) {
      final badge = Tooltip(
        message: codes.map((c) => c.replaceAll('_', ' ')).join(', '),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: errorCount > 0 ? AppColors.red : AppColors.warn,
              size: 20,
            ),
            const SizedBox(width: 2),
            Text(
              '${errorCount + warningCount}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
      trailingWidget = trailing == null
          ? badge
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [badge, const SizedBox(width: 8), trailing!],
            );
    }

    return Material(
      color: AppColors.cardBg,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.sandHover,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (type != null && type!.isNotEmpty) ...[
                const SizedBox(width: 12),
                TypeBadge(type!, tone: _typeTone(type!)),
              ],
              if (statusTone != null) ...[
                const SizedBox(width: 12),
                StatusPill(detail!, tone: statusTone),
              ],
              if (trailingWidget != null) ...[
                const SizedBox(width: 12),
                trailingWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
