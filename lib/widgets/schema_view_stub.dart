import 'package:flutter/material.dart';

/// Non-web fallback — the mermaid diagram renders only in the web build.
Widget schemaView() => const Center(
  child: Padding(
    padding: EdgeInsets.all(24),
    child: Text(
      'The schema diagram is available in the web app.',
      textAlign: TextAlign.center,
    ),
  ),
);
