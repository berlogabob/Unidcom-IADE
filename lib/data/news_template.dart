import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'news_taxonomy.dart';

/// XLSX download hook. The excel package has no data-validation writer;
/// Taxonomia supplies the allowed values and parsing enforces them.
Uint8List buildNewsTemplate() {
  final book = Excel.createExcel();
  book.rename('Sheet1', 'News');
  book['News'].appendRow(newsColumns.map(TextCellValue.new).toList());
  final lists = [newsTypes, newsScientificAreas, newsMemberTypes, newsLabs];
  book['Taxonomia'].appendRow(
    [
      'Type values',
      'Scientific areas',
      'Member types',
      'Labs',
    ].map(TextCellValue.new).toList(),
  );
  for (var i = 0; i < newsTypes.length; i++) {
    book['Taxonomia'].appendRow([
      for (final values in lists)
        TextCellValue(i < values.length ? values[i] : ''),
    ]);
  }
  book.setDefaultSheet('News');
  return Uint8List.fromList(book.encode()!);
}

class NewsImportRow {
  final int rowNumber;
  final Map<String, dynamic> data;
  final List<String> errors;
  final List<String> warnings;

  const NewsImportRow(this.rowNumber, this.data, this.errors, this.warnings);
}

class NewsParseResult {
  /// Includes invalid rows for correction, but excludes duplicate title+year.
  final List<NewsImportRow> rows;

  /// File errors use row 1; other keys are physical spreadsheet row numbers.
  final Map<int, List<String>> errors;

  const NewsParseResult(this.rows, this.errors);
}

String _clean(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text == '-' ? '' : text;
}

String? _match(String value, List<String> allowed) {
  for (final item in allowed) {
    if (item.toLowerCase() == value.toLowerCase()) return item;
  }
  return null;
}

/// Allocate a unique slug, reserving it in [used] for subsequent news rows.
String newsSlug(String title, Set<String> used) {
  final ascii = unicode.nfkd(title).replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  var base = ascii.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
  base = base.replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.isEmpty) base = 'news';
  var slug = base;
  var suffix = 2;
  while (used.contains(slug)) {
    slug = '$base-${suffix++}';
  }
  used.add(slug);
  return slug;
}

/// No IO. Review warnings are retained in import_note; blocking errors prevent
/// draft insertion. Earlier/empty years need a real year before import.
NewsParseResult parseNewsFile(
  List<int> bytes,
  String filename, {
  Iterable<String> existingSlugs = const [],
}) {
  List<List<dynamic>> cells;
  try {
    if (filename.toLowerCase().endsWith('.csv')) {
      cells = Csv(
        skipEmptyLines: false,
      ).decode(utf8.decode(bytes).replaceFirst('\uFEFF', ''));
    } else if (filename.toLowerCase().endsWith('.xlsx')) {
      final book = Excel.decodeBytes(bytes);
      // Hande's original workbooks use different News sheet names.
      final candidates = book.tables.values
          .where(
            (sheet) =>
                sheet.rows.isNotEmpty &&
                sheet.rows.first
                        .take(6)
                        .map((c) => _clean(c?.value).toLowerCase())
                        .join('|') ==
                    newsColumns.join('|'),
          )
          .toList();
      final sheet =
          book.tables['News'] ??
          (candidates.length == 1 ? candidates.single : null);
      if (sheet == null) throw const FormatException('No unique News sheet');
      cells = sheet.rows.map((r) => r.map((c) => c?.value).toList()).toList();
    } else {
      throw const FormatException('Expected .xlsx or .csv');
    }
  } catch (error) {
    return NewsParseResult([], {
      1: ['Cannot read file: $error'],
    });
  }
  if (cells.isEmpty) {
    return const NewsParseResult([], {
      1: ['Missing header'],
    });
  }
  final headers = cells.first.map((c) => _clean(c).toLowerCase()).toList();
  if (newsColumns.any((c) => !headers.contains(c)) ||
      headers.toSet().length != headers.length) {
    return const NewsParseResult([], {
      1: ['Missing or duplicate columns'],
    });
  }
  final rows = <NewsImportRow>[];
  final errors = <int, List<String>>{};
  final used = existingSlugs.toSet();
  final seen = <String>{};
  for (var i = 1; i < cells.length; i++) {
    final values = cells[i];
    if (values.every((v) => _clean(v).isEmpty)) continue;
    String get(String key) {
      final col = headers.indexOf(key);
      return col < 0 || col >= values.length ? '' : _clean(values[col]);
    }

    final problems = <String>[];
    final notes = <String>[];
    final title = get('title');
    if (title.isEmpty) problems.add('Missing title');
    final rawYear = get('year');
    final year = RegExp(r'^[1-9][0-9]{3}(?:\.0)?$').hasMatch(rawYear)
        ? int.parse(rawYear.substring(0, 4))
        : null;
    if (year == null) problems.add('A four-digit year is required: $rawYear');
    final originalType = get('type');
    var type = _match(originalType, newsTypes);
    if (type == null &&
        originalType.isNotEmpty &&
        !originalType.startsWith('[')) {
      final matches = newsTypes
          .where(
            (t) =>
                t.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '').toLowerCase() ==
                originalType.toLowerCase(),
          )
          .toList();
      if (matches.length == 1) type = matches.single;
    }
    type ??= 'Unclassified';
    if (type == 'Unclassified') {
      notes.add(
        'Unclassified type: ${originalType.isEmpty ? "empty type" : originalType}',
      );
    } else if (type != originalType) {
      notes.add('$originalType -> $type');
    }
    List<String> taxonomy(String column, List<String> allowed) {
      var value = get(column);
      if (column == 'lab') {
        value = value.replaceFirst(RegExp(r'\.lab$', caseSensitive: false), '');
      }
      if (value.isEmpty) return [];
      final canonical = _match(value, allowed);
      if (canonical == null) {
        problems.add('$column: non-matching taxonomy value ($value)');
        return [];
      }
      return [canonical];
    }

    final areas = taxonomy('scientific area', newsScientificAreas);
    final members = taxonomy('type of member', newsMemberTypes);
    final labs = taxonomy('lab', newsLabs);
    if (labs.isEmpty) notes.add('missing lab');
    final excerpt = String.fromCharCodes(title.runes.take(150));
    if (title.runes.length > 150) {
      notes.add('title > 150 chars; excerpt truncated');
    }
    final slug = newsSlug(title, used);
    final key = jsonEncode([title, year ?? rawYear]);
    if (!seen.add(key)) {
      errors[i + 1] = ['duplicate title+year'];
      continue;
    }
    if (problems.isNotEmpty) errors[i + 1] = problems;
    final provenance = get('source_file');
    if (get('row').isNotEmpty) notes.add('source row: ${get("row")}');
    for (final key in [
      'type_note',
      'scientific_area_note',
      'member_type_note',
      'lab_note',
      'year_note',
    ]) {
      if (get(key).isNotEmpty) notes.add(get(key));
    }
    rows.add(
      NewsImportRow(
        i + 1,
        {
          'title': title,
          'year': year,
          'date': year == null ? null : '$year-01-01',
          'date_precision': 'year',
          'slug': slug,
          'excerpt': excerpt,
          'news_type': type,
          'scientific_areas': areas,
          'member_types': members,
          'lab': labs,
          'source': 'import:${provenance.isEmpty ? filename : provenance}',
          'import_note': notes.isEmpty ? null : notes.toSet().join('; '),
          'published': false,
        },
        problems,
        notes,
      ),
    );
  }
  return NewsParseResult(rows, errors);
}
