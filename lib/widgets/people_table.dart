import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Rui's v1.0 brief PE-1: the People table.
class PeopleTable extends StatelessWidget {
  const PeopleTable({
    super.key,
    required this.people,
    required this.lastSignIn,
    required this.issues,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> people;
  final Map<String, DateTime?> lastSignIn;
  final Map<String, int> issues;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        dataTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('ORCID')),
          DataColumn(label: Text('Last login')),
          DataColumn(label: Text('Issues'), numeric: true),
          DataColumn(label: Text('UNIDCOM status')),
          DataColumn(label: Text('Website')),
        ],
        rows: [
          for (final person in people)
            _row(person, (person['id'] as String)),
        ],
      ),
    );
  }

  DataRow _row(Map<String, dynamic> person, String id) {
    final name = person['preferred_name'] as String? ?? 'Unnamed';
    return DataRow(
      onSelectChanged: (_) => onOpen(id),
      cells: [
        DataCell(Text(name), onTap: () => onOpen(id)),
        DataCell(Text(_type(person['membership_type'] as String?))),
        DataCell(Text(_orcid(person['orcid']))),
        DataCell(Text(_date(lastSignIn[id]))),
        DataCell(Text('${issues[id] ?? 0}')),
        DataCell(Text(_status(person['profile_status'] as String?))),
        DataCell(Text(person['public_visibility'] == true
            ? 'Published'
            : 'Not published')),
      ],
    );
  }

  static String _type(String? value) => value == null
      ? '—'
      : value.replaceFirstMapped(
          RegExp(r'^.'),
          (match) => match.group(0)!.toUpperCase(),
        ).replaceAll('_', ' ');

  static String _orcid(dynamic value) =>
      value is String && value.isNotEmpty ? 'Linked' : 'Not linked';

  static String _date(DateTime? value) {
    if (value == null) return 'Never';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  static String _status(String? value) => switch (value) {
    'to_validate' => 'To be validated',
    'draft' => 'Draft',
    'pending_review' => 'Submitted',
    'under_review' => 'Under review',
    'approved' => 'Approved',
    _ => '—',
  };
}
