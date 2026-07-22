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
  });

  final String title;
  final int? year;
  final String? type;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (year != null) year.toString(),
      if (type != null && type!.isNotEmpty) type!,
      if (detail != null && detail!.isNotEmpty) detail!,
    ].join(' · ');

    return ListTile(
      title: Text(title),
      subtitle: meta.isEmpty ? null : Text(meta),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
