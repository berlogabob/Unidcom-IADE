import 'dart:async';

import 'package:flutter/material.dart';

/// Search text field that debounces [onChanged] by 300 ms, so callers can
/// fire queries directly without owning their own Timer.
class SearchBarField extends StatefulWidget {
  const SearchBarField({
    super.key,
    this.controller,
    this.label = 'Search',
    this.onChanged,
    this.keyboardType,
  });

  final TextEditingController? controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  @override
  State<SearchBarField> createState() => _SearchBarFieldState();
}

class _SearchBarFieldState extends State<SearchBarField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => widget.onChanged?.call(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged == null ? null : _changed,
    );
  }
}
