import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/public/person_page.dart';

Map<String, dynamic> author(String id) => {
  'outputs': {'id': id, 'title': id},
};

List<String> ids(List<Map<String, dynamic>> rows) =>
    rows.map(outputIdOf).whereType<String>().toList();

void main() {
  final rows = [author('a'), author('b'), author('c'), author('d')];

  test('no favourites leaves order untouched', () {
    expect(ids(orderByFeatured(rows, [])), ['a', 'b', 'c', 'd']);
  });

  test('favourites pin to the top in the order they were starred', () {
    expect(ids(orderByFeatured(rows, ['c', 'a'])), ['c', 'a', 'b', 'd']);
  });

  test('unpinned tail keeps its original order', () {
    expect(ids(orderByFeatured(rows, ['d'])), ['d', 'a', 'b', 'c']);
  });

  test('unknown favourite ids are ignored, not rendered as gaps', () {
    expect(ids(orderByFeatured(rows, ['ghost', 'b'])), ['b', 'a', 'c', 'd']);
  });

  test('starring appends, so array order is starring order', () {
    expect(nextFeatured(['a'], 'b'), ['a', 'b']);
    expect(nextFeatured([], 'a'), ['a']);
  });

  test('starring an already-starred output unstars it', () {
    expect(nextFeatured(['a', 'b', 'c'], 'b'), ['a', 'c']);
  });

  test('starring is refused at the cap, returning the list unchanged', () {
    final full = ['a', 'b', 'c', 'd', 'e'];
    expect(full.length, maxFeaturedOutputs);
    expect(identical(nextFeatured(full, 'f'), full), isTrue);
  });

  test('unstarring still works when at the cap', () {
    final full = ['a', 'b', 'c', 'd', 'e'];
    expect(nextFeatured(full, 'c'), ['a', 'b', 'd', 'e']);
  });

  test('featuredOf tolerates a missing or empty column', () {
    expect(featuredOf({}), isEmpty);
    expect(featuredOf({'featured_outputs': null}), isEmpty);
    expect(featuredOf({'featured_outputs': ['x']}), ['x']);
  });
}
