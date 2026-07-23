import 'dart:async';

import 'package:flutter/material.dart';

import 'search_bar.dart';

/// Search-and-pick dialog reused for people, outputs, clusters, labs and
/// objectives. Returns the chosen row (or null on cancel).
Future<Map<String, dynamic>?> showSearchPicker(
  BuildContext context, {
  required String title,
  required Future<List<Map<String, dynamic>>> Function(String query) search,
  required String Function(Map<String, dynamic>) label,
  String Function(Map<String, dynamic>)? subtitle,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _SearchPickerDialog(
      title: title,
      search: search,
      label: label,
      subtitle: subtitle,
    ),
  );
}

class _SearchPickerDialog extends StatefulWidget {
  const _SearchPickerDialog({
    required this.title,
    required this.search,
    required this.label,
    this.subtitle,
  });

  final String title;
  final Future<List<Map<String, dynamic>>> Function(String) search;
  final String Function(Map<String, dynamic>) label;
  final String Function(Map<String, dynamic>)? subtitle;

  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  Timer? _debounce;
  late Future<List<Map<String, dynamic>>> _results = widget.search('');

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _results = widget.search(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            SearchBarField(onChanged: _onChanged),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return const Center(child: Text('No results'));
                  }
                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final sub = widget.subtitle?.call(row) ?? '';
                      return ListTile(
                        title: Text(widget.label(row)),
                        subtitle: sub.isEmpty ? null : Text(sub),
                        onTap: () => Navigator.of(context).pop(row),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
