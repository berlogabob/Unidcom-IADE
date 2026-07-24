import 'package:flutter/material.dart';

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
    final meta = [
      if (year != null) year.toString(),
      if (type != null && type!.isNotEmpty) type!,
      if (detail != null && detail!.isNotEmpty) detail!,
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
              color: errorCount > 0
                  ? Theme.of(context).colorScheme.error
                  : Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 2),
            Text('${errorCount + warningCount}'),
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

    return ListTile(
      title: Text(title),
      subtitle: meta.isEmpty ? null : Text(meta),
      trailing: trailingWidget,
      onTap: onTap,
    );
  }
}
