import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/outputs_tree.dart';

void main() {
  test('shared prefixes collapse into one branch, ordered by sort_order', () {
    final roots = buildTree([
      {
        'segments': ['Livros', 'Autoria de Livro', 'Único autor'],
        'sort_order': 1,
      },
      {
        'segments': ['Livros', 'Autoria de Livro', 'Co-autor'],
        'sort_order': 0,
      },
      {
        'segments': ['Conferência em congressos'],
        'sort_order': 2,
      },
    ]);

    expect(roots.map((n) => n.label), ['Livros', 'Conferência em congressos']);

    final livros = roots.first;
    expect(livros.children.single.label, 'Autoria de Livro');
    // sort_order 0 (Co-autor) precedes sort_order 1 (Único autor)
    expect(livros.children.single.children.map((n) => n.label), [
      'Co-autor',
      'Único autor',
    ]);

    // a 1-segment path is a top-level leaf
    expect(roots.last.children, isEmpty);
  });
}
