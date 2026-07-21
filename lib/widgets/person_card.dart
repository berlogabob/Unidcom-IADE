import 'package:flutter/material.dart';

class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.name,
    this.membershipType,
    this.status,
    this.onTap,
  });

  final String name;
  final String? membershipType;
  final String? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: status == null ? null : Text(status!),
        trailing: membershipType == null
            ? null
            : Chip(label: Text(membershipType!)),
        onTap: onTap,
      ),
    );
  }
}
