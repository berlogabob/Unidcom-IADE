/// The director's output classification, and the arithmetic around it.
///
/// Flutter-free and Supabase-free on purpose, like `request_status.dart`: this
/// is the part that is easy to get subtly wrong, so it has to be the part that
/// is easy to test.
///
/// ## The shape of the data, and why it looked broken
///
/// `output_taxonomy` holds 74 leaf paths, a ragged tree 1–4 levels deep.
/// `outputs.category_path` stores one of those paths — except that the importer
/// took it from a spreadsheet with a fixed four-column layout
/// (Macro-tipo / Tipo / Subtipo / Papel) and shallow branches were padded out
/// to four by *repeating* a level, positionally:
///
/// ```
/// depth 1 → [L1, L1, L1, L1]      depth 3 → [L1, L1, L2, L3]
/// depth 2 → [L1, L1, L2, L2]      depth 4 → [L1, L2, L3, L4]
/// ```
///
/// That is why Rui's screen showed
/// `Organização de Seminários e Conferências › Organização de Seminários e
/// Conferências › Membro da comissão científica… › Membro da comissão
/// científica…` — the same label twice, twice over. Collapsing consecutive
/// duplicates inverts the padding exactly: 294 of the 301 classified rows then
/// match a taxonomy leaf verbatim, and the other 7 are a single da/de spelling
/// difference, repaired by migration.
///
/// [categorySegments] collapses on read regardless, so display is correct on
/// data the migration has not touched — an old export, a preview branch.
library;

/// U+203A, spaces both sides. The separator the importer wrote and the reports
/// read; changing it would orphan every stored path.
const categorySeparator = ' › ';

/// A node in the taxonomy tree. [children] empty means leaf.
class TaxonomyNode {
  const TaxonomyNode(this.label, this.children);

  final String label;
  final List<TaxonomyNode> children;
}

/// Builds the tree from flat leaf paths, preserving the order they arrive in
/// (`output_taxonomy.sort_order` — the director's ordering, not alphabetical).
List<TaxonomyNode> buildTaxonomy(List<List<String>> leafPaths) {
  // Insertion-ordered maps all the way down, so first-seen order wins.
  final roots = <String, Map<String, dynamic>>{};
  for (final path in leafPaths) {
    var level = roots;
    for (final label in path) {
      final node = level.putIfAbsent(
        label,
        () => <String, Map<String, dynamic>>{},
      );
      level = node.cast<String, Map<String, dynamic>>();
    }
  }
  return _nodes(roots);
}

List<TaxonomyNode> _nodes(Map<String, Map<String, dynamic>> level) => [
  for (final entry in level.entries)
    TaxonomyNode(
      entry.key,
      _nodes(entry.value.cast<String, Map<String, dynamic>>()),
    ),
];

/// Splits a stored `category_path` into its real segments, collapsing the
/// legacy four-column padding. Correct on both the padded and the repaired
/// form, so it can be relied on before and after the migration.
List<String> categorySegments(String? path) {
  final raw = (path ?? '')
      .split(categorySeparator)
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty);
  final segments = <String>[];
  for (final segment in raw) {
    if (segments.isEmpty || segments.last != segment) segments.add(segment);
  }
  return segments;
}

/// A `like` pattern matching this branch and everything under it, so stopping
/// the cascade early filters the whole subtree.
///
/// ponytail: no escaping. None of the ~90 taxonomy labels contains `%` or `_`,
/// and no label is a prefix of a sibling's, so this cannot over-match. If the
/// taxonomy ever gains a label with a wildcard in it, escape here.
String categoryPrefix(List<String> segments) =>
    '${segments.join(categorySeparator)}%';

/// The denormalised columns that go with a path.
///
/// `report_data()` builds the PDF's sections from `macro_type` and its
/// subsections from `subtype` (see 20260728150000_report_data.sql), so writing
/// `category_path` alone would quietly drop a new output out of the annual
/// report. This reproduces the importer's positional layout.
///
/// ponytail: the honest fix is deleting the three columns and having
/// report_data() read category_path. Deferred — it means changing the Edge
/// Function and the report at the same time as the UI.
Map<String, dynamic> categoryFields(List<String> segments) {
  if (segments.isEmpty) {
    return {'macro_type': null, 'type': null, 'subtype': null};
  }
  final depth = segments.length;
  return {
    'macro_type': segments[0],
    'type': depth >= 4 ? segments[1] : segments[0],
    'subtype': depth == 1
        ? segments[0]
        : depth >= 4
        ? segments[2]
        : segments[1],
  };
}

/// The children available under [selected], or the roots when nothing is
/// picked. Empty means the branch ends here and the cascade should stop.
List<TaxonomyNode> childrenAt(
  List<TaxonomyNode> roots,
  List<String> selected,
) {
  var level = roots;
  for (final label in selected) {
    final match = level.where((node) => node.label == label);
    if (match.isEmpty) return const [];
    level = match.first.children;
  }
  return level;
}
