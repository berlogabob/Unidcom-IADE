import 'package:flutter/material.dart';

class OutputRow extends StatelessWidget {
  const OutputRow({
    super.key,
    required this.title,
    this.year,
    this.type,
    this.detail,
    this.trailing,
  });

  final String title;
  final int? year;
  final String? type;
  final String? detail;
  final Widget? trailing;

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
    );
  }
}
