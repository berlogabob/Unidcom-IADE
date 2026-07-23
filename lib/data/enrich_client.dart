import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase.dart';

const _crossrefUa = 'UNIDCOM-Directory/1.0 (mailto:andre.berloga@gmail.com)';

// Institution tokens used to disambiguate ORCID homonyms (normalized, lowercased).
const _orgTokens = [
  'iade',
  'unidcom',
  'universidade europeia',
  'instituto de artes visuais', // IADE's full legal name as ORCID stores it
];

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

String _givenKey(String? value) {
  final parts = _normalize(value).split(' ').where((p) => p.isNotEmpty);
  return parts.isEmpty ? '' : parts.first;
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
    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 8));
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

/// Picks the best ORCID match from an `expanded-search` result list for
/// [fullName], disambiguating homonyms by institution. Returns null when the
/// match is ambiguous — better to suggest nothing than a wrong guess.
({String orcid, double confidence})? pickOrcidCandidate(
  List<dynamic> results,
  String? fullName,
) {
  final targetGiven = _givenKey(fullName);
  final targetFamily = _familyKey(fullName);
  if (targetGiven.isEmpty || targetFamily.isEmpty) return null;

  bool nameMatches(Map result) =>
      _familyKey(result['family-names'] as String?) == targetFamily &&
      _givenKey(result['given-names'] as String?) == targetGiven;

  bool atOrg(Map result) {
    final names = (result['institution-name'] as List? ?? [])
        .whereType<String>()
        .map(_normalize);
    return names.any((n) => _orgTokens.any((t) => n.contains(t)));
  }

  final matches = results.whereType<Map>().where(nameMatches).toList();
  final affiliated = matches.where(atOrg).toList();

  Map? chosen;
  double confidence;
  if (affiliated.length == 1) {
    chosen = affiliated.single;
    confidence = 0.7;
  } else if (affiliated.isEmpty && matches.length == 1) {
    chosen = matches.single;
    confidence = 0.5;
  } else {
    return null; // ambiguous
  }

  final orcid = _bareOrcid(chosen['orcid-id'] as String?);
  return orcid == null ? null : (orcid: orcid, confidence: confidence);
}

/// Extracts a Ciência ID from an ORCID `/person` payload's external
/// identifiers (matching CiênciaVitae by type name or URL). Null if absent.
String? cienciaIdFromOrcidPerson(Map<String, dynamic> profile) {
  final ids =
      (profile['external-identifiers']
              as Map?)?['external-identifier'] as List? ??
      [];
  for (final id in ids.whereType<Map>()) {
    final type = _normalize(id['external-id-type'] as String?);
    final url = _normalize(
      (id['external-id-url'] as Map?)?['value'] as String?,
    );
    if (type.contains('ciencia') || url.contains('cienciavitae')) {
      final value = _clean(id['external-id-value'] as String?);
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}

/// Builds person suggestions mined from an ORCID `/person` profile, only for
/// fields that are currently empty on [person]. Pure — no I/O.
List<Map<String, dynamic>> orcidProfileSuggestions({
  required String personId,
  required Map<String, dynamic> person,
  required Map<String, dynamic> profile,
}) {
  final suggestions = <Map<String, dynamic>>[];
  bool empty(String field) => _clean(person[field] as String?).isEmpty;
  void add(String field, String? value, double confidence) {
    final clean = _clean(value);
    if (clean.isEmpty || !empty(field)) return;
    suggestions.add({
      'subject_type': 'person',
      'subject_id': personId,
      'field': field,
      'current_value': person[field],
      'suggested_value': clean,
      'source': 'orcid',
      'confidence': confidence,
    });
  }

  add('ciencia_id', cienciaIdFromOrcidPerson(profile), 0.8);
  add('bio', (profile['biography'] as Map?)?['content'] as String?, 0.6);

  final emails = (profile['emails'] as Map?)?['email'] as List? ?? [];
  final email = emails.whereType<Map>().toList()
    ..sort((a, b) {
      int rank(Map e) =>
          (e['primary'] == true ? 0 : 1) + (e['verified'] == true ? 0 : 1);
      return rank(a).compareTo(rank(b));
    });
  if (email.isNotEmpty) add('email', email.first['email'] as String?, 0.7);

  final name = profile['name'] as Map?;
  final legal =
      (name?['credit-name'] as Map?)?['value'] as String? ??
      '${(name?['given-names'] as Map?)?['value'] ?? ''} '
          '${(name?['family-name'] as Map?)?['value'] ?? ''}';
  add('legal_name', legal, 0.5);

  return suggestions;
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
        .select('preferred_name,orcid,ciencia_id,bio,email,legal_name')
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
    // The ORCID we can mine a profile from: stored, or discovered below.
    String? resolvedOrcid = hasOrcid
        ? _bareOrcid(person['orcid'] as String?)
        : null;

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

      if (hasOrcid || resolvedOrcid != null) continue;
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
        resolvedOrcid = orcid;
        break;
      }
    }

    // No ORCID yet — try a name search, disambiguated by institution.
    if (resolvedOrcid == null) {
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
        final candidate = pickOrcidCandidate(results, name);
        if (candidate != null) {
          suggestions.add({
            'subject_type': 'person',
            'subject_id': personId,
            'field': 'orcid',
            'current_value': null,
            'suggested_value': candidate.orcid,
            'source': 'orcid',
            'confidence': candidate.confidence,
          });
          resolvedOrcid = candidate.orcid;
        }
      }
    }

    // Mine the ORCID profile for Ciência ID / bio / email / legal name.
    if (resolvedOrcid != null) {
      final profile = await _getJson(
        Uri.parse('https://pub.orcid.org/v3.0/$resolvedOrcid/person'),
        headers: {'Accept': 'application/json'},
      );
      if (profile != null) {
        suggestions.addAll(
          orcidProfileSuggestions(
            personId: personId,
            person: person,
            profile: profile,
          ),
        );
      }
    }

    return _insertNewSuggestions(suggestions);
  } catch (error) {
    throw Exception(error);
  }
}
