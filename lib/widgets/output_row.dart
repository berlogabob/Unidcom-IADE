import 'package:flutter/material.dart';

class OutputRow extends StatelessWidget {
  const OutputRow({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(title));
  }
}
