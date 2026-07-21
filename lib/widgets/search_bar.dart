import 'package:flutter/material.dart';

class SearchBarField extends StatelessWidget {
  const SearchBarField({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextField(decoration: InputDecoration(labelText: 'Search'));
  }
}
