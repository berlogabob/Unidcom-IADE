import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/news_taxonomy.dart';
import 'package:unidcom_iade/data/news_template.dart';

NewsParseResult parse(
  List<List<Object?>> rows, {
  List<String> slugs = const [],
}) => parseNewsFile(
  utf8.encode(csv.encode([newsColumns, ...rows])),
  'news.csv',
  existingSlugs: slugs,
);

void main() {
  test('empty template round trip, sheets and complete taxonomy', () {
    final bytes = buildNewsTemplate();
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys, ['News', 'Taxonomia']);
    expect(
      book['News'].rows.single.map((c) => c!.value.toString()),
      newsColumns,
    );
    expect(book['Taxonomia'].maxRows, newsTypes.length + 1);
    final result = parseNewsFile(bytes, 'Template.XLSX');
    expect(result.rows, isEmpty);
    expect(result.errors, isEmpty);
  });

  test('filled template round trip and year precision', () {
    final book = Excel.decodeBytes(buildNewsTemplate());
    book['News'].appendRow([
      TextCellValue('Olá!'),
      DoubleCellValue(2026.0),
      TextCellValue('CONFERENCE'),
      TextCellValue('design'),
      TextCellValue('integrated'),
      TextCellValue('bid.lab'),
    ]);
    final result = parseNewsFile(book.encode()!, 'News.xlsx');
    expect(result.errors, isEmpty);
    expect(result.rows.single.data, containsPair('date', '2026-01-01'));
    expect(result.rows.single.data, containsPair('date_precision', 'year'));
    expect(result.rows.single.data['lab'], ['BID']);
    expect(result.rows.single.data['news_type'], '[Events] conference');
    expect(result.rows.single.data['slug'], 'ola');
    expect(result.rows.single.data['published'], false);
    expect(
      result.rows.single.warnings,
      contains('CONFERENCE -> [Events] conference'),
    );
  });

  test('all canonical types and unprefixed forms match case insensitively', () {
    for (final type in newsTypes) {
      final bare = type.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');
      for (final value in [
        type.toUpperCase(),
        if (bare.isNotEmpty) bare.toUpperCase(),
      ]) {
        final row = parse([
          ['Title', 2025, value, 'SCIENCE', 'collaborator', 'DfH'],
        ]).rows.single;
        expect(row.data['news_type'], type, reason: value);
        expect(row.errors, isEmpty);
      }
    }
  });

  test('dash is empty; missing and unknown type remain reviewable', () {
    for (final type in [' - ', '', 'unknown']) {
      final row = parse([
        ['T', 2026, type, '-', '-', '-'],
      ]).rows.single;
      expect(row.data['news_type'], 'Unclassified');
      expect(row.data['scientific_areas'], isEmpty);
      expect(row.data['member_types'], isEmpty);
      expect(row.data['lab'], isEmpty);
      expect(row.warnings.join(';'), contains('missing lab'));
      expect(row.warnings.join(';'), contains('Unclassified'));
      expect(row.errors, isEmpty);
    }
  });

  test('unknown taxonomy values block rather than silently losing data', () {
    final result = parse([
      ['T', 2026, 'seminar', 'Other', 'Integrated; Other', 'Unknown'],
    ]);
    expect(result.rows.single.errors, hasLength(3));
    expect(result.errors[2], result.rows.single.errors);
  });

  test('invalid years, Earlier and missing title need correction', () {
    expect(
      parse([
        ['', 2026, '-', '', '', ''],
      ]).errors[2],
      ['Missing title'],
    );
    for (final year in ['Earlier', '', '-', '26', '2026.5', '0000', '10000']) {
      final result = parse([
        ['T', year, '-', '', '', ''],
      ]);
      expect(result.errors[2], hasLength(1));
      expect(result.rows.single.data['date'], isNull);
    }
    for (final year in ['1000', '9999', '2025.0']) {
      expect(
        parse([
          ['T', year, '-', '', '', ''],
        ]).errors,
        isEmpty,
      );
    }
  });

  test(
    'Python-compatible slugs collide within the file and with existing slugs',
    () {
      final result = parse(
        [
          ['Olá!', 2026],
          ['Ola', 2026],
          ['Ola-2', 2026],
          ['Ola', 2025],
          ['中文', 2026],
        ],
        slugs: ['ola'],
      );
      expect(result.rows.map((r) => r.data['slug']), [
        'ola-2',
        'ola-3',
        'ola-2-2',
        'ola-4',
        'news',
      ]);
    },
  );

  test('duplicate title+year retained once and reported on physical row', () {
    final result = parse([
      [' T ', 2026],
      ['T', '2026.0'],
      ['T', 2025],
    ]);
    expect(result.rows, hasLength(2));
    expect(result.errors[3], ['duplicate title+year']);
  });

  test('excerpt truncates by Unicode characters and retains full title', () {
    for (final title in ['A' * 151, '😀' * 151]) {
      final row = parse([
        [title, 2026],
      ]).rows.single;
      expect((row.data['excerpt'] as String).runes.length, 150);
      expect(row.data['title'], title);
      expect(row.data['import_note'], contains('excerpt truncated'));
    }
  });

  test('CSV BOM, quoted commas, escaped quotes and embedded newlines', () {
    const title = 'Research, "design"\nand art';
    final bytes = utf8.encode(
      '\uFEFF${csv.encode([
        newsColumns,
        [title, 2026],
      ])}',
    );
    final result = parseNewsFile(bytes, 'NEWS.CSV');
    expect(result.errors, isEmpty);
    expect(result.rows.single.data['title'], title);
  });

  test('bad files, headers and missing sheets return file errors', () {
    for (final input in [
      (utf8.encode('bad'), 'a.xlsx'),
      (utf8.encode(''), 'a.csv'),
      (utf8.encode('title,year\nT,2026'), 'a.csv'),
      (utf8.encode('bad'), 'a.xls'),
      (Excel.createExcel().encode()!, 'a.xlsx'),
      (utf8.encode('${newsColumns.join(",")},title\n'), 'a.csv'),
      ([255], 'a.csv'),
    ]) {
      expect(parseNewsFile(input.$1, input.$2).errors[1], isNotEmpty);
    }
  });

  test('blank rows ignored and physical row numbers retained', () {
    final result = parse([
      [],
      ['T', 'Earlier'],
    ]);
    expect(result.rows.single.rowNumber, 3);
    expect(result.errors.keys, [3]);
  });

  test(
    'Hande workbook sheet names accepted when header uniquely identifies News',
    () {
      final book = Excel.decodeBytes(buildNewsTemplate());
      book.rename('News', 'FCT Report 2026');
      book['FCT Report 2026'].appendRow([
        TextCellValue('T'),
        IntCellValue(2025),
      ]);
      expect(parseNewsFile(book.encode()!, 'Hande.xlsx').rows, hasLength(1));
    },
  );

  test(
    'all 181 real normalized rows preserve Python slugs, taxonomy and provenance',
    () {
      final bytes = File('test/fixtures/news_normalized.csv').readAsBytesSync();
      final result = parseNewsFile(bytes, 'news_normalized.csv');
      final original = csv.decode(
        utf8.decode(bytes).replaceFirst('\uFEFF', ''),
      );
      final headers = original.first.map((v) => v.toString()).toList();
      expect(result.rows, hasLength(181));
      expect(result.rows.map((r) => r.data['slug']).toSet(), hasLength(181));
      for (var i = 0; i < result.rows.length; i++) {
        final row = result.rows[i];
        String get(String field) =>
            original[i + 1][headers.indexOf(field)].toString();
        expect(row.data['title'], get('title'));
        expect(row.data['slug'], get('slug'));
        expect(row.data['news_type'], get('type'));
        for (final field in {
          'scientific_areas': 'scientific area',
          'member_types': 'type of member',
          'lab': 'lab',
        }.entries) {
          var expected = get(field.value);
          if (field.key == 'lab') expected = expected.replaceFirst('.Lab', '');
          final allowed = switch (field.key) {
            'scientific_areas' => newsScientificAreas,
            'member_types' => newsMemberTypes,
            _ => newsLabs,
          };
          if (expected.isNotEmpty && !allowed.contains(expected)) {
            expect(row.errors.join(';'), contains(expected));
            expect(row.data[field.key], isEmpty);
          } else {
            expect(
              row.data[field.key],
              expected.isEmpty ? isEmpty : [expected],
            );
          }
        }
        expect(row.data['source'], 'import:${get("source_file")}');
        expect(row.data['import_note'], contains('source row: ${get("row")}'));
        expect(
          (row.data['excerpt'] as String).runes.length,
          lessThanOrEqualTo(150),
        );
        if (get('year') == 'Earlier' || get('year').isEmpty) {
          expect(row.errors, isNotEmpty);
        } else {
          expect(row.data['date'], '${get("year")}-01-01');
        }
      }
    },
  );
}
