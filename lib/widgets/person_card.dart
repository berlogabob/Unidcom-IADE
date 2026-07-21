import 'package:flutter/material.dart';

class PersonCard extends StatelessWidget {
  const PersonCard({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(name));
  }
}
