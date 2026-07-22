import 'package:supabase_flutter/supabase_flutter.dart';

final db = Supabase.instance.client;

bool get isAdmin => db.auth.currentUser?.appMetadata['role'] == 'admin';

String _error(Object error) =>
    error is PostgrestException || error is AuthException
    ? (error as dynamic).message as String
    : error.toString();

Future<List<Map<String, dynamic>>> fetchPeople({
  String? query,
  String? membershipType,
  String? status,
  String? profileStatus,
  bool missingOrcid = false,
  bool needsVerification = false,
  bool hasOutputs = false,
}) async {
  try {
    final q = query?.trim();
    final select = hasOutputs
        ? 'id, preferred_name, membership_type, status, email, photo_url, profile_status, output_authors!inner(output_id)'
        : 'id, preferred_name, membership_type, status, email, photo_url, profile_status';
    var request = db
        .from('people')
        .select(select)
        .filter('merged_into', 'is', null);
    if (q != null && q.isNotEmpty) {
      request = request.ilike('preferred_name', '%$q%');
    }
    if (membershipType != null) {
      request = request.eq('membership_type', membershipType);
    }
    if (status != null) {
      request = request.eq('status', status);
    }
    if (profileStatus != null) {
      request = request.eq('profile_status', profileStatus);
    }
    if (missingOrcid) {
      request = request.or('orcid.is.null,orcid.eq.');
    }
    if (needsVerification) {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 183))
          .toIso8601String();
      request = request.or(
        'last_verified_at.is.null,last_verified_at.lt.$cutoff',
      );
    }
    final rows = await request.order('preferred_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<Map<String, dynamic>> fetchPerson(String id) async {
  try {
    final row = await db
        .from('people')
        .select(
          'id, preferred_name, legal_name, bio, membership_type, status, email, photo_url, '
          'orcid, ciencia_id, profile_status, public_visibility, last_verified_at, '
          'join_date, exit_date, '
          'output_authors(role, author_position, outputs(id,title,reporting_year,type,subtype,doi,url)), '
          'person_tags(tags(name))',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchAllActivePeople() async {
  try {
    final rows = await db
        .from('people')
        .select(
          'id, preferred_name, legal_name, email, orcid, ciencia_id, membership_type, status, bio, photo_url',
        )
        .filter('merged_into', 'is', null)
        .order('preferred_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<List<Map<String, dynamic>>>> fetchMergeCandidates() async {
  return groupMergeCandidates(await fetchAllActivePeople());
}

/// Groups people whose names are duplicates via token-set containment:
/// two names match when one's normalized token set is a subset of the other's
/// (e.g. "Sara Gancho" ⊆ "Sara Patrícia Martins Gancho"). Distinct middle
/// names ("Paulo Teixeira Costa" vs "Paulo Nuno Costa") therefore do NOT match.
///
// ponytail: O(n²) containment scan over active people; fine at lab scale.
// Ceiling: a bare 2-token name ("Paulo Costa") can transitively link two fuller
// distinct names into one review group — acceptable (admin picks per-field in the
// merge matrix); add a similarity threshold if that becomes noisy.
List<List<Map<String, dynamic>>> groupMergeCandidates(
  List<Map<String, dynamic>> people,
) {
  final sets = <Set<String>>[];
  final valid = <int>[]; // indices of people with a usable (>=2 token) name
  for (var i = 0; i < people.length; i++) {
    final tokens = _normalizeName(people[i]['preferred_name'] as String?)
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toSet();
    sets.add(tokens);
    if (tokens.length >= 2) valid.add(i);
  }

  // Union-find over people whose token sets are in a subset/superset relation.
  final parent = List<int>.generate(people.length, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  for (var a = 0; a < valid.length; a++) {
    for (var b = a + 1; b < valid.length; b++) {
      final i = valid[a], j = valid[b];
      if (sets[i].containsAll(sets[j]) || sets[j].containsAll(sets[i])) {
        parent[find(i)] = find(j);
      }
    }
  }

  final groups = <int, List<Map<String, dynamic>>>{};
  for (final i in valid) {
    groups.putIfAbsent(find(i), () => []).add(people[i]);
  }
  final candidates = groups.values.where((group) => group.length > 1).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return candidates;
}

Future<void> mergePeople(
  String survivorId,
  List<String> loserIds,
  Map<String, dynamic> fields,
) async {
  try {
    await db.rpc(
      'merge_people',
      params: {
        'p_survivor': survivorId,
        'p_losers': loserIds,
        'p_fields': fields,
      },
    );
  } catch (error) {
    throw Exception(_error(error));
  }
}

String _normalizeName(String? value) {
  const from = 'áàãâäåāăąçćčďéèêëēėęěíìîïīįłñńňóòõôöōőřśšșťúùûüūůűýÿžźż';
  const to = 'aaaaaaaaacccdeeeeeeeeiiiiiilnnnooooooorssstuuuuuuyyzzz';
  final text = (value ?? '').toLowerCase().split('').map((char) {
    final index = from.indexOf(char);
    return index == -1 ? char : to[index];
  }).join();
  return text
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .join(' ');
}

Future<void> updatePerson(String id, Map<String, dynamic> fields) async {
  try {
    await db.from('people').update(fields).eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<String> createPerson(Map<String, dynamic> fields) async {
  try {
    final row = await db.from('people').insert(fields).select('id').single();
    return row['id'] as String;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> updateOutput(String id, Map<String, dynamic> fields) async {
  try {
    await db.from('outputs').update(fields).eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> updateMyProfile(Map<String, dynamic> fields) async {
  try {
    final userId = db.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    await db.from('people').update(fields).eq('auth_user_id', userId);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> approvePerson(String id) async {
  await updatePerson(id, {
    'profile_status': 'approved',
    'public_visibility': true,
    'last_verified_at': DateTime.now().toIso8601String(),
  });
}

Future<void> approveOutput(String id) async {
  try {
    await db
        .from('outputs')
        .update({'approval_status': 'approved'})
        .eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<Map<String, dynamic>?> fetchMyPerson() async {
  try {
    final userId = db.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await db
        .from('people')
        .select('id, preferred_name, bio, photo_url, email, orcid, ciencia_id')
        .eq('auth_user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> linkPersonToMe(String personId) async {
  try {
    final userId = db.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');
    await db.from('people').update({'auth_user_id': userId}).eq('id', personId);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchPendingPeople() async {
  try {
    final rows = await db
        .from('people')
        .select('id, preferred_name, email, profile_status, created_at')
        .neq('profile_status', 'approved')
        .order('preferred_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchPendingOutputs() async {
  try {
    final rows = await db
        .from('outputs')
        .select('id, title, reporting_year, type, approval_status, created_at')
        .eq('approval_status', 'pending')
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchStalePeople() async {
  try {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 183))
        .toIso8601String();
    final rows = await db
        .from('people')
        .select('id, preferred_name, email, last_verified_at, membership_type')
        .or('last_verified_at.is.null,last_verified_at.lt.$cutoff')
        .order('preferred_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchPendingSuggestions() async {
  try {
    final rows = await db
        .from('enrichment_suggestions')
        .select()
        .eq('status', 'pending')
        .order('created_at');
    final suggestions = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    for (final suggestion in suggestions) {
      final table = suggestion['subject_type'] == 'person'
          ? 'people'
          : 'outputs';
      final nameField = suggestion['subject_type'] == 'person'
          ? 'preferred_name'
          : 'title';
      final subject = await db
          .from(table)
          .select(nameField)
          .eq('id', suggestion['subject_id'] as String)
          .maybeSingle();
      suggestion['subject_name'] =
          subject?[nameField] as String? ?? 'Missing subject';
    }
    return suggestions;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchSuggestionsForPerson(
  String personId,
) async {
  try {
    final rows = await db
        .from('enrichment_suggestions')
        .select()
        .eq('subject_type', 'person')
        .eq('subject_id', personId)
        .eq('status', 'pending')
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> acceptSuggestion(String id) async {
  try {
    final suggestion = await db
        .from('enrichment_suggestions')
        .select()
        .eq('id', id)
        .single();
    final subjectId = suggestion['subject_id'] as String;
    final field = suggestion['field'] as String;
    final value = suggestion['suggested_value'];
    if (suggestion['subject_type'] == 'person') {
      await updatePerson(subjectId, {field: value});
    } else {
      await updateOutput(subjectId, {field: value});
    }
    await db
        .from('enrichment_suggestions')
        .update({'status': 'accepted'})
        .eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> rejectSuggestion(String id) async {
  try {
    await db
        .from('enrichment_suggestions')
        .update({'status': 'rejected'})
        .eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchPeopleForStats() async {
  try {
    final rows = await db
        .from('people')
        .select('id, preferred_name, membership_type, orcid, last_verified_at')
        .filter('merged_into', 'is', null)
        .order('preferred_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchOutputsForStats() async {
  try {
    final rows = await db
        .from('outputs')
        .select('id, type, subtype, reporting_year')
        .order('type');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchAuthorCounts() async {
  try {
    final rows = await db
        .from('output_authors')
        .select('person_id, people(preferred_name)');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchOutputs({
  String? query,
  int? year,
  String? type,
  String? quartile,
  String? approvalStatus,
}) async {
  try {
    final q = query?.trim();
    var request = db
        .from('outputs')
        .select(
          'id, title, reporting_year, type, subtype, doi, url, approval_status, output_authors(people(id,preferred_name))',
        );
    if (q != null && q.isNotEmpty) {
      request = request.ilike('title', '%$q%');
    }
    if (year != null) {
      request = request.eq('reporting_year', year);
    }
    if (type != null) {
      request = request.eq('type', type);
    }
    if (quartile != null) {
      request = request.ilike('subtype', '%quartil $quartile%');
    }
    if (approvalStatus != null) {
      request = request.eq('approval_status', approvalStatus);
    }
    final rows = await request
        .order('reporting_year', ascending: false)
        .order('title');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<Map<String, dynamic>> fetchOutput(String id) async {
  try {
    final row = await db
        .from('outputs')
        .select(
          'id, title, reporting_year, type, subtype, category_path, doi, url, approval_status, '
          'output_authors(role, author_position, people(id, preferred_name, membership_type, status)), '
          'project_outputs(projects(id, title, status))',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<String>> fetchDistinctOutputTypes() async {
  try {
    final rows = await db.from('outputs').select('type');
    final types =
        rows
            .map((row) => row['type'] as String?)
            .whereType<String>()
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return types;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<int>> fetchDistinctOutputYears() async {
  try {
    final rows = await db.from('outputs').select('reporting_year');
    final years =
        rows
            .map((row) => row['reporting_year'] as int?)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    return years;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchOutputsForReport({
  int? year,
  String? type,
}) async {
  try {
    var request = db
        .from('outputs')
        .select(
          'id, title, reporting_year, type, subtype, doi, url, output_authors(people(preferred_name))',
        );
    if (year != null) {
      request = request.eq('reporting_year', year);
    }
    if (type != null && type.isNotEmpty) {
      request = request.eq('type', type);
    }
    final rows = await request
        .order('reporting_year', ascending: false)
        .order('title');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<List<Map<String, dynamic>>> fetchProjects() async {
  try {
    final rows = await db
        .from('projects')
        .select(
          'id, title, acronym, description, start_date, end_date, status, created_at',
        )
        .order('title');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<Map<String, dynamic>> fetchProject(String id) async {
  try {
    final row = await db
        .from('projects')
        .select(
          'id, title, acronym, description, total_budget, currency, '
          'start_date, end_date, status, public_visibility, approval_status, '
          'project_members(role, people(id, preferred_name, membership_type, status)), '
          'project_outputs(outputs(id, title, reporting_year, type, doi, url))',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<String> createProject(Map<String, dynamic> fields) async {
  try {
    final row = await db.from('projects').insert(fields).select('id').single();
    return row['id'] as String;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> updateProject(String id, Map<String, dynamic> fields) async {
  try {
    await db.from('projects').update(fields).eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> addProjectMember(
  String projectId,
  String personId, {
  String? role,
}) async {
  try {
    await db.from('project_members').upsert({
      'project_id': projectId,
      'person_id': personId,
      'role': role,
    }, onConflict: 'project_id,person_id');
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> removeProjectMember(String projectId, String personId) async {
  try {
    await db
        .from('project_members')
        .delete()
        .eq('project_id', projectId)
        .eq('person_id', personId);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> linkProjectOutput(String projectId, String outputId) async {
  try {
    await db.from('project_outputs').upsert({
      'project_id': projectId,
      'output_id': outputId,
    }, onConflict: 'project_id,output_id');
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> unlinkProjectOutput(String projectId, String outputId) async {
  try {
    await db
        .from('project_outputs')
        .delete()
        .eq('project_id', projectId)
        .eq('output_id', outputId);
  } catch (error) {
    throw Exception(_error(error));
  }
}
