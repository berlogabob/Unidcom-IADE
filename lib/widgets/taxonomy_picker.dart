import 'package:flutter/material.dart';

import '../data/taxonomy.dart';
import 'queue_list.dart';

/// Sequential selection down the output taxonomy, one dropdown per level.
///
/// Rui, 2026-08-10, looking at a row of thirteen 70-character filter pills:
///
/// > instead of this - use the same three comboboxes as filter. this works for
/// > both filtering my outputs as well as when i click +add
///
/// So it is one widget with two callers, and the same interaction in each.
///
/// Levels appear as they are earned: level 1 always, level *n+1* only once
/// level *n* is chosen and that branch actually has children. The tree is
/// ragged — `Missões de internacionalização` is a leaf at depth 1 and shows a
/// single box, while `Livros › Capítulos › indexados ISI › Co-autor` shows
/// four. Stopping early is a real answer, not an incomplete one: it means the
/// whole subtree.
///
/// Stateless by design — [value] is the caller's, so the filter can put it in a
/// URL and the editor can put it in a form without this widget holding a second
/// copy that drifts.
class TaxonomyPicker extends StatelessWidget {
  const TaxonomyPicker({
    super.key,
    required this.roots,
    required this.value,
    required this.onChanged,
    this.labels = const ['Category', 'Subcategory', 'Detail', 'Role'],
    this.width = 260,
  });

  /// The tree, from `fetchOutputTaxonomy()`.
  final List<TaxonomyNode> roots;

  /// Segments picked so far. Empty means nothing picked — "All".
  final List<String> value;

  final ValueChanged<List<String>> onChanged;

  /// One per depth. The tree is at most 4 deep; a deeper one falls back to a
  /// numbered label rather than throwing.
  final List<String> labels;

  final double width;

  @override
  Widget build(BuildContext context) {
    final dropdowns = <Widget>[];

    // One box per already-chosen level, plus one for the next choice — which is
    // what makes the cascade grow and shrink as you go.
    for (var depth = 0; depth <= value.length; depth++) {
      final options = childrenAt(roots, value.take(depth).toList());
      // The branch ended. Nothing left to ask.
      if (options.isEmpty) break;
      dropdowns.add(
        filterDropdown(
          depth < labels.length ? labels[depth] : 'Level ${depth + 1}',
          depth < value.length ? value[depth] : null,
          [for (final node in options) node.label],
          (picked) {
            // Truncate at this level: choosing a new Category must not leave a
            // Subcategory from the previous branch behind, selecting nothing.
            final next = value.take(depth).toList();
            if (picked != null) next.add(picked);
            onChanged(next);
          },
          width: width,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: dropdowns,
    );
  }
}
