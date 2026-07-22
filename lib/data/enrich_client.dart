import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase.dart';

const _crossrefUa = 'UNIDCOM-Directory/1.0 (mailto:andre.berloga@gmail.com)';

String _clean(String? value) =>
    (value ?? '').trim().split(RegExp(r'\s+')).join(' ');

String _normalize(String? value) {
  const from = 'áàâãäåÁÀÂÃÄÅéèêëÉÈÊËíìîïÍÌÎÏóòôõöÓÒÔÕÖúùûüÚÙÛÜçÇñÑ';
  const to = 'aaaaaaAAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcCnN';
  var text = _clean(value).toLowerCase();
  for (var i = 0; i < from.length; i++) {
    text = text.replaceAll(from[i], to[i].toLowerCase());
  }
  return text;
}

String _familyKey(String? value) {
  final parts = _normalize(value).split(' ');
  return parts.isEmpty ? '' : parts.last;
}

String? _cleanDoi(String? value) {
  final match = RegExp(
    r'10\.[^\s"<>]+',
    caseSensitive: false,
  ).firstMatch(value ?? '');
  return match?.group(0)?.replaceFirst(RegExp(r'[).,;]+$'), '').toLowerCase();
}

String? _bareOrcid(String? value) {
  final match = RegExp(
    r'\d{4}-\d{4}-\d{4}-[\dX]{4}',
    caseSensitive: false,
  ).firstMatch(value ?? '');
  return match?.group(0)?.toUpperCase();
}

String _titleKey(String? value) =>
    _normalize(value).replaceAll(RegExp(r'[^\w\s]'), '');

Future<Map<String, dynamic>?> _getJson(
  Uri url, {
  Map<String, String>? headers,
}) async {
  try {
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 404 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<bool> _pendingExists(Map<String, dynamic> row) async {
  final rows = await db
      .from('enrichment_suggestions')
      .select('id')
      .eq('status', 'pending')
      .eq('subject_type', row['subject_type'] as String)
      .eq('subject_id', row['subject_id'] as String)
      .eq('field', row['field'] as String)
      .eq('suggested_value', row['suggested_value'] as String)
      .limit(1);
  return rows.isNotEmpty;
}

Future<int> _insertNewSuggestions(
  List<Map<String, dynamic>> suggestions,
) async {
  var inserted = 0;
  for (final row in suggestions) {
    try {
      if (await _pendingExists(row)) continue;
      await db.from('enrichment_suggestions').insert(row);
      inserted++;
    } catch (_) {
      // Skip duplicate/racy rows and RLS/network hiccups per suggestion.
    }
  }
  return inserted;
}

Future<int> enrichPerson(String personId) async {
  try {
    final person = await db
        .from('people')
        .select('preferred_name,orcid')
        .eq('id', personId)
        .single();
    final name = person['preferred_name'] as String?;
    final hasOrcid = _clean(person['orcid'] as String?).isNotEmpty;
    final rows = await db
        .from('output_authors')
        .select('outputs(id,title,doi)')
        .eq('person_id', personId);
    final outputs = rows
        .map((row) => row['outputs'])
        .whereType<Map<String, dynamic>>()
        .where((output) => _cleanDoi(output['doi'] as String?) != null);

    final suggestions = <Map<String, dynamic>>[];
    var hasOrcidSuggestion = false;
    for (final output in outputs) {
      final doi = _cleanDoi(output['doi'] as String?);
      if (doi == null) continue;
      final data = await _getJson(
        Uri.parse('https://api.crossref.org/works/${Uri.encodeComponent(doi)}'),
        headers: {'User-Agent': _crossrefUa},
      );
      final message = (data?['message'] as Map?)?.cast<String, dynamic>();
      if (message == null) continue;

      final title = (message['title'] as List?)?.firstOrNull?.toString();
      final suggestedTitle = _clean(title);
      final storedTitle = output['title'] as String?;
      if (suggestedTitle.isNotEmpty &&
          _titleKey(suggestedTitle) != _titleKey(storedTitle)) {
        suggestions.add({
          'subject_type': 'output',
          'subject_id': output['id'],
          'field': 'title',
          'current_value': storedTitle,
          'suggested_value': suggestedTitle,
          'source': 'crossref',
          'confidence': 0.6,
        });
      }

      if (hasOrcid) continue;
      for (final author in (message['author'] as List? ?? [])) {
        if (author is! Map) continue;
        final orcid = _bareOrcid(author['ORCID'] as String?);
        if (orcid == null ||
            _familyKey(author['family'] as String?) != _familyKey(name)) {
          continue;
        }
        suggestions.add({
          'subject_type': 'person',
          'subject_id': personId,
          'field': 'orcid',
          'current_value': null,
          'suggested_value': orcid,
          'source': 'crossref',
          'confidence': 0.9,
        });
        hasOrcidSuggestion = true;
      }
    }

    if (!hasOrcid && !hasOrcidSuggestion) {
      final parts = _clean(name).split(' ');
      if (parts.length > 1) {
        final data = await _getJson(
          Uri.https('pub.orcid.org', '/v3.0/expanded-search/', {
            'q':
                'given-names:${parts.take(parts.length - 1).join(' ')} '
                'AND family-name:${parts.last}',
          }),
          headers: {'Accept': 'application/json'},
        );
        final results = data?['expanded-result'] as List? ?? [];
        if (results.length == 1 && results.single is Map) {
          final orcid = _bareOrcid(
            (results.single as Map)['orcid-id'] as String?,
          );
          if (orcid != null) {
            suggestions.add({
              'subject_type': 'person',
              'subject_id': personId,
              'field': 'orcid',
              'current_value': null,
              'suggested_value': orcid,
              'source': 'orcid',
              'confidence': 0.4,
            });
          }
        }
      }
    }

    return _insertNewSuggestions(suggestions);
  } catch (error) {
    throw Exception(error);
  }
}
