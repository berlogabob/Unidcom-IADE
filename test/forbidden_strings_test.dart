import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Rui, 25 Sep 2026 (UI decisions for the pilot): words the v1.0 portal must never show.
const forbidden = [
  'Auto-published',
  'auto-published',
  'Welcome back',
  'My Dashboard',
  "'Sync now'",
  "'ORCID Sync'",
  'sync automatically',
];

void main() {
  test('no forbidden UI strings in lib/', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final word in forbidden) {
          if (line.contains(word)) hits.add('${f.path}:${i + 1}: $word');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
