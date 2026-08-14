import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/taxonomy.dart';

// Fixture mirrors the real ragged shape: a depth-1 branch, a depth-2 branch and
// a depth-4 branch, in the seed's order rather than alphabetical.
final _fixture = <List<String>>[
  ['Livros', 'Capítulos de livros', 'Capítulos indexados', 'Único autor'],
  ['Livros', 'Capítulos de livros', 'Capítulos indexados', 'Co-autor'],
  ['Livros', 'Autoria de Livro', 'Livro indexado', 'Único autor'],
  ['Organização de Seminários e Conferências', 'Chair de conferências'],
  ['Missões de internacionalização'],
];

void main() {
  group('buildTaxonomy', () {
    final roots = buildTaxonomy(_fixture);

    test('shared prefixes merge into one node', () {
      expect(roots.length, 3);
      expect(roots.first.label, 'Livros');
      expect(roots.first.children.map((node) => node.label), [
        'Capítulos de livros',
        'Autoria de Livro',
      ]);
    });

    test('seed order wins over alphabetical', () {
      // 'Autoria de Livro' sorts first but is seeded second; the director's
      // ordering is the one the reports use.
      expect(roots.first.children.first.label, 'Capítulos de livros');
      expect(roots.map((node) => node.label).toList(), [
        'Livros',
        'Organização de Seminários e Conferências',
        'Missões de internacionalização',
      ]);
    });

    test('ragged depths coexist; leaves have no children', () {
      expect(childrenAt(roots, ['Missões de internacionalização']), isEmpty);
      expect(
        childrenAt(roots, ['Organização de Seminários e Conferências']).length,
        1,
      );
      expect(
        childrenAt(roots, [
          'Livros',
          'Capítulos de livros',
          'Capítulos indexados',
        ]).map((node) => node.label),
        ['Único autor', 'Co-autor'],
      );
    });

    test('an unknown branch yields nothing rather than throwing', () {
      expect(childrenAt(roots, ['Nope']), isEmpty);
      expect(childrenAt(roots, ['Livros', 'Nope']), isEmpty);
    });
  });

  group('categorySegments: the padding Rui photographed', () {
    // The four positional shapes the importer produced, verified against all
    // 301 classified rows in scripts/out/outputs.json.
    test('depth 1 stored as [L1,L1,L1,L1]', () {
      expect(categorySegments('Missões › Missões › Missões › Missões'), [
        'Missões',
      ]);
    });

    test('depth 2 stored as [L1,L1,L2,L2]', () {
      // This is the exact shape behind the doubled breadcrumb on his screen.
      expect(
        categorySegments(
          'Organização de Seminários e Conferências › '
          'Organização de Seminários e Conferências › '
          'Membro da comissão científica › Membro da comissão científica',
        ),
        [
          'Organização de Seminários e Conferências',
          'Membro da comissão científica',
        ],
      );
    });

    test('depth 3 stored as [L1,L1,L2,L3]', () {
      expect(categorySegments('Artigos › Artigos › Quartil Q1 › Co-autor'), [
        'Artigos',
        'Quartil Q1',
        'Co-autor',
      ]);
    });

    test('depth 4 is already canonical and survives untouched', () {
      expect(categorySegments('Livros › Capítulos › Indexados › Co-autor'), [
        'Livros',
        'Capítulos',
        'Indexados',
        'Co-autor',
      ]);
    });

    test('repaired paths round-trip unchanged', () {
      expect(categorySegments('Livros › Capítulos de livros'), [
        'Livros',
        'Capítulos de livros',
      ]);
    });

    test('null, empty and whitespace give nothing, not a phantom segment', () {
      expect(categorySegments(null), isEmpty);
      expect(categorySegments(''), isEmpty);
      expect(categorySegments('   ›  › '), isEmpty);
    });

    test('a genuine repeat that is not adjacent is kept', () {
      // Collapsing is consecutive-only: A › B › A is three real levels.
      expect(categorySegments('A › B › A'), ['A', 'B', 'A']);
    });
  });

  group('categoryPrefix', () {
    test('matches the branch and everything under it', () {
      expect(
        categoryPrefix(['Livros', 'Capítulos de livros']),
        'Livros › Capítulos de livros%',
      );
    });

    test('an empty selection matches everything', () {
      expect(categoryPrefix([]), '%');
    });
  });

  group('matchesCategory: the in-memory twin of the SQL prefix filter', () {
    test('empty selection is All — even the unclassified pass', () {
      expect(matchesCategory('Livros', const []), isTrue);
      expect(matchesCategory(null, const []), isTrue);
    });

    test('a branch matches itself and everything under it', () {
      expect(matchesCategory('Livros', const ['Livros']), isTrue);
      expect(
        matchesCategory('Livros › Capítulos de livros', const ['Livros']),
        isTrue,
      );
      expect(matchesCategory('Exposições', const ['Livros']), isFalse);
    });

    test('segments, not string prefixes — no sibling over-match', () {
      expect(matchesCategory('Livros e afins', const ['Livros']), isFalse);
    });

    test('unclassified rows drop out of any real selection', () {
      expect(matchesCategory(null, const ['Livros']), isFalse);
      expect(matchesCategory('', const ['Livros']), isFalse);
    });

    test('correct on legacy padded paths, like categorySegments', () {
      expect(
        matchesCategory('Livros › Livros › Capítulos de livros', const [
          'Livros',
          'Capítulos de livros',
        ]),
        isTrue,
      );
    });
  });

  group('categoryFields: what report_data() groups on', () {
    test('depth 1 fills all three columns with the single label', () {
      expect(categoryFields(['Missões']), {
        'macro_type': 'Missões',
        'type': 'Missões',
        'subtype': 'Missões',
      });
    });

    test('depth 2 repeats the root into type', () {
      expect(categoryFields(['Organização', 'Chair']), {
        'macro_type': 'Organização',
        'type': 'Organização',
        'subtype': 'Chair',
      });
    });

    test('depth 3 keeps the root in type and the middle in subtype', () {
      expect(categoryFields(['Artigos', 'Quartil Q1', 'Co-autor']), {
        'macro_type': 'Artigos',
        'type': 'Artigos',
        'subtype': 'Quartil Q1',
      });
    });

    test('depth 4 maps straight through', () {
      expect(categoryFields(['Livros', 'Capítulos', 'Indexados', 'Co-autor']), {
        'macro_type': 'Livros',
        'type': 'Capítulos',
        'subtype': 'Indexados',
      });
    });

    test('nothing picked writes nulls, not empty strings', () {
      expect(categoryFields([]), {
        'macro_type': null,
        'type': null,
        'subtype': null,
      });
    });
  });
}
