/// Max outputs a person may pin to their profile. Mirrors the
/// `people_featured_outputs_max` check constraint.
const maxFeaturedOutputs = 5;

/// Ids of the outputs a person pinned, in the order they starred them.
List<String> featuredOf(Map<String, dynamic> person) =>
    (person['featured_outputs'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();

String? outputIdOf(Map<String, dynamic> author) =>
    (author['outputs'] as Map<String, dynamic>?)?['id'] as String?;

/// Pinned outputs first in [featured] order, everything else in its original
/// order. Partition rather than sort: Dart's List.sort isn't stable, so sorting
/// would scramble the unpinned tail. Featured ids with no matching row (output
/// deleted or unlinked) simply drop out — the array is not FK-enforced.
List<Map<String, dynamic>> orderByFeatured(
  List<Map<String, dynamic>> authors,
  List<String> featured,
) => [
  for (final id in featured) ...authors.where((a) => outputIdOf(a) == id),
  ...authors.where((a) => !featured.contains(outputIdOf(a))),
];

/// Toggles [outputId] in [featured]. Unstarring always works; starring is
/// refused at the cap, signalled by returning [featured] itself unchanged.
List<String> nextFeatured(List<String> featured, String outputId) {
  final next = List<String>.from(featured);
  if (next.remove(outputId)) return next;
  if (next.length >= maxFeaturedOutputs) return featured;
  return next..add(outputId);
}
