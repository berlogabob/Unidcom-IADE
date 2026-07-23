import 'package:supabase_flutter/supabase_flutter.dart';

final db = Supabase.instance.client;

bool get isAdmin => db.auth.currentUser?.appMetadata['role'] == 'admin';

/// Layer 1 — mandatory membership (one per person/year): the single source
/// shared by the person editor, the logbook, and the dashboard.
const membershipTypes = ['integrated', 'collaborator', 'external'];
const membershipLabels = {
  'integrated': 'Integrated members',
  'collaborator': 'Collaborators',
  'external': 'External',
};

/// Layer 2 — starter vocabulary of optional roles (from the raw `Papel` column).
/// Merged with the distinct labels already in the DB by [fetchRoleVocabulary];
/// users can also type a new value.
const seedRoleVocabulary = [
  'PhD student',
  'Advisory Board',
  'Staff',
  'Scientific Coordination',
  'Science Management',
  'Executive Direction',
  'Mentor',
  'Other',
];

/// Full-DB export/import order: base tables first, then link tables that FK into
/// them. Upsert resolves on each table's PK. Keep in sync with the schema — the
/// diagram (web/schema.mmd) is the authoritative picture.
const dbTables = [
  // base entities
  'people',
  'outputs',
  'projects',
  'clusters',
  'labs',
  'objectives',
  'collaborations',
  'tags',
  // link tables (FK into the above)
  'output_authors',
  'project_members',
  'project_outputs',
  'project_clusters',
  'project_labs',
  'project_objectives',
  'objective_clusters',
  'lab_members',
  'lab_objectives',
  'lab_collaborations',
  'project_collaborations',
  'person_tags',
  'person_roles',
  'enrichment_suggestions',
];

/// Reads one table's rows — used by the read-only table browser.
Future<List<Map<String, dynamic>>> fetchTable(String name) async {
  try {
    final rows = await db.from(name).select();
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

/// Reads every table (admin RLS sees all rows) into a table -> rows map.
Future<Map<String, List<Map<String, dynamic>>>> exportAll() async {
  try {
    final data = <String, List<Map<String, dynamic>>>{};
    for (final table in dbTables) {
      final rows = await db.from(table).select();
      data[table] = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    }
    return data;
  } catch (error) {
    throw Exception(_error(error));
  }
}

/// Upserts each present table in dependency order. Non-destructive (never
/// deletes). In-app the admin's is_admin() is true, so protect_people_cols
/// allows governance columns — no trigger juggling needed (unlike restore.py).
Future<void> importAll(Map<String, List<Map<String, dynamic>>> data) async {
  try {
    for (final table in dbTables) {
      final rows = data[table];
      if (rows == null || rows.isEmpty) continue;
      await db.from(table).upsert(rows);
    }
  } catch (error) {
    throw Exception(_error(error));
  }
}

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
          'join_date, exit_date, phd, notes, integration_year, auth_user_id, '
          'output_authors(role, author_position, outputs(id,title,reporting_year,type,subtype,doi,url)), '
          'lab_members(is_coordinator, year, labs(id, code, name)), '
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
    final tokens = _normalizeName(
      people[i]['preferred_name'] as String?,
    ).split(' ').where((s) => s.isNotEmpty).toSet();
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

/// Records changed fields to change_log (the "what / how / when" audit trail).
/// Best-effort: a logging failure never blocks the underlying edit. Only fields
/// whose trimmed value actually changed are logged; [source] is manual | orcid |
/// crossref | import | sync_out. Actor = the signed-in auth user.
Future<void> logChanges(
  String subjectType,
  String subjectId,
  Map<String, dynamic> before,
  Map<String, dynamic> after, {
  String source = 'manual',
}) async {
  final actor = db.auth.currentUser?.id;
  final rows = <Map<String, dynamic>>[];
  after.forEach((field, newValue) {
    final oldStr = before[field]?.toString().trim() ?? '';
    final newStr = newValue?.toString().trim() ?? '';
    if (oldStr == newStr) return;
    rows.add({
      'subject_type': subjectType,
      'subject_id': subjectId,
      'field': field,
      'old_value': oldStr.isEmpty ? null : oldStr,
      'new_value': newStr.isEmpty ? null : newStr,
      'source': source,
      'actor': actor,
    });
  });
  if (rows.isEmpty) return;
  try {
    await db.from('change_log').insert(rows);
  } catch (_) {
    // ponytail: audit is best-effort; never fail the edit because logging hiccuped.
  }
}

/// Recent audit rows, newest first, with `subject_name` and `actor_name`
/// resolved in batch (person/output subjects, and actor via people.auth_user_id).
Future<List<Map<String, dynamic>>> fetchChangeLog({int limit = 200}) async {
  try {
    final rows =
        (await db
                .from('change_log')
                .select()
                .order('changed_at', ascending: false)
                .limit(limit))
            .map((row) => Map<String, dynamic>.from(row))
            .toList();

    final personIds = <String>{};
    final outputIds = <String>{};
    final actorIds = <String>{};
    for (final row in rows) {
      final sid = row['subject_id'] as String?;
      if (sid != null && row['subject_type'] == 'person') personIds.add(sid);
      if (sid != null && row['subject_type'] == 'output') outputIds.add(sid);
      final actor = row['actor'] as String?;
      if (actor != null) actorIds.add(actor);
    }

    final names = <String, String>{};
    if (personIds.isNotEmpty) {
      for (final p in await db
          .from('people')
          .select('id, preferred_name')
          .inFilter('id', personIds.toList())) {
        names['person:${p['id']}'] = p['preferred_name'] as String? ?? '';
      }
    }
    if (outputIds.isNotEmpty) {
      for (final o in await db
          .from('outputs')
          .select('id, title')
          .inFilter('id', outputIds.toList())) {
        names['output:${o['id']}'] = o['title'] as String? ?? '';
      }
    }
    final actors = <String, String>{};
    if (actorIds.isNotEmpty) {
      for (final p in await db
          .from('people')
          .select('auth_user_id, preferred_name')
          .inFilter('auth_user_id', actorIds.toList())) {
        final au = p['auth_user_id'] as String?;
        if (au != null) actors[au] = p['preferred_name'] as String? ?? '';
      }
    }

    for (final row in rows) {
      row['subject_name'] = names['${row['subject_type']}:${row['subject_id']}'];
      row['actor_name'] = actors[row['actor']];
    }
    return rows;
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
    final subjectType = suggestion['subject_type'] as String;
    final subjectId = suggestion['subject_id'] as String;
    final field = suggestion['field'] as String;
    final value = suggestion['suggested_value'];
    if (subjectType == 'person') {
      await updatePerson(subjectId, {field: value});
    } else {
      await updateOutput(subjectId, {field: value});
    }
    await logChanges(
      subjectType,
      subjectId,
      {field: suggestion['current_value']},
      {field: value},
      source: suggestion['source'] as String? ?? 'orcid',
    );
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
        .select(
          'id, type, subtype, reporting_year, fct_selected, verified_online',
        )
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
          'full_reference, fct_selected, verified_online, macro_type, output_status, source, '
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
          'id, title, acronym, description, start_date, end_date, status, '
          'funding, category, created_at',
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
          'start_date, end_date, status, funding, category, notes, risk, '
          'public_visibility, approval_status, '
          'project_members(role, people(id, preferred_name, membership_type, status)), '
          'project_outputs(outputs(id, title, reporting_year, type, doi, url)), '
          'project_clusters(clusters(id, code, name)), '
          'project_labs(labs(id, code, name)), '
          'project_objectives(objectives(id, code, name)), '
          'project_collaborations(collaborations(id, name, kind))',
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

// ---------------------------------------------------------------- link helpers
/// Generic upsert/delete for the many-to-many join tables (project_clusters,
/// project_labs, project_objectives, lab_objectives, ...). Saves ~10 near-copies.
Future<void> upsertLink(
  String table,
  Map<String, dynamic> row,
  String onConflict,
) async {
  try {
    await db.from(table).upsert(row, onConflict: onConflict);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> deleteLink(String table, Map<String, String> filters) async {
  try {
    var query = db.from(table).delete();
    filters.forEach((column, value) => query = query.eq(column, value));
    await query;
  } catch (error) {
    throw Exception(_error(error));
  }
}

// ---------------------------------------------------------------------- labs
Future<List<Map<String, dynamic>>> fetchLabs() async {
  try {
    final rows = await db
        .from('labs')
        .select(
          'id, code, name, overview, notes, '
          'lab_members(person_id), lab_objectives(count), project_labs(count)',
        )
        .order('name');
    // lab_members now has a `year` in its PK, so a person across N years yields N
    // rows — collapse to a distinct-person count so the roster isn't inflated.
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      final members = (map['lab_members'] as List<dynamic>? ?? [])
          .map((m) => (m as Map<String, dynamic>)['person_id'])
          .toSet();
      map['lab_members'] = [
        {'count': members.length},
      ];
      return map;
    }).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<Map<String, dynamic>> fetchLab(String id) async {
  try {
    final row = await db
        .from('labs')
        .select(
          'id, code, name, overview, notes, '
          'lab_members(is_coordinator, year, people(id, preferred_name, membership_type, status)), '
          'lab_objectives(objectives(id, code, name)), '
          'project_labs(projects(id, title, status)), '
          'lab_collaborations(collaborations(id, name, kind))',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<String> createLab(Map<String, dynamic> fields) async {
  try {
    final row = await db.from('labs').insert(fields).select('id').single();
    return row['id'] as String;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> updateLab(String id, Map<String, dynamic> fields) async {
  try {
    await db.from('labs').update(fields).eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> deleteLab(String id) async {
  try {
    await db.from('labs').delete().eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> addLabMember(
  String labId,
  String personId, {
  bool isCoordinator = false,
  int? year,
}) async {
  await upsertLink('lab_members', {
    'lab_id': labId,
    'person_id': personId,
    'is_coordinator': isCoordinator,
    'year': year ?? DateTime.now().year,
  }, 'lab_id,person_id,year');
}

Future<void> removeLabMember(String labId, String personId, {int? year}) =>
    deleteLink('lab_members', {
      'lab_id': labId,
      'person_id': personId,
      'year': '${year ?? DateTime.now().year}',
    });

// ------------------------------------------------------------------ clusters
Future<List<Map<String, dynamic>>> fetchClusters() async {
  try {
    final rows = await db
        .from('clusters')
        .select(
          'id, code, name, concern, notes, '
          'objective_clusters(count), project_clusters(count)',
        )
        .order('code');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<Map<String, dynamic>> fetchCluster(String id) async {
  try {
    final row = await db
        .from('clusters')
        .select(
          'id, code, name, concern, notes, '
          'objective_clusters(objectives(id, code, name)), '
          'project_clusters(projects(id, title, status))',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<String> createCluster(Map<String, dynamic> fields) async {
  try {
    final row = await db.from('clusters').insert(fields).select('id').single();
    return row['id'] as String;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> updateCluster(String id, Map<String, dynamic> fields) async {
  try {
    await db.from('clusters').update(fields).eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> deleteCluster(String id) async {
  try {
    await db.from('clusters').delete().eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

// ---------------------------------------------------------------- objectives
Future<List<Map<String, dynamic>>> fetchObjectives() async {
  try {
    final rows = await db
        .from('objectives')
        .select(
          'id, code, name, description, kpis, '
          'objective_clusters(clusters(code)), '
          'project_objectives(count), lab_objectives(count)',
        )
        .order('code');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<Map<String, dynamic>> fetchObjective(String id) async {
  try {
    final row = await db
        .from('objectives')
        .select(
          'id, code, name, description, kpis, source, '
          'objective_clusters(clusters(id, code, name)), '
          'lab_objectives(labs(id, code, name)), '
          'project_objectives(projects(id, title, status))',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<String> createObjective(Map<String, dynamic> fields) async {
  try {
    final row = await db
        .from('objectives')
        .insert(fields)
        .select('id')
        .single();
    return row['id'] as String;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> updateObjective(String id, Map<String, dynamic> fields) async {
  try {
    await db.from('objectives').update(fields).eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> deleteObjective(String id) async {
  try {
    await db.from('objectives').delete().eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

// -------------------------------------------------- project link management
Future<void> linkProjectCluster(String projectId, String clusterId) =>
    upsertLink('project_clusters', {
      'project_id': projectId,
      'cluster_id': clusterId,
    }, 'project_id,cluster_id');

Future<void> unlinkProjectCluster(String projectId, String clusterId) =>
    deleteLink('project_clusters', {
      'project_id': projectId,
      'cluster_id': clusterId,
    });

Future<void> linkProjectLab(String projectId, String labId) => upsertLink(
  'project_labs',
  {'project_id': projectId, 'lab_id': labId},
  'project_id,lab_id',
);

Future<void> unlinkProjectLab(String projectId, String labId) =>
    deleteLink('project_labs', {'project_id': projectId, 'lab_id': labId});

Future<void> linkProjectObjective(String projectId, String objectiveId) =>
    upsertLink('project_objectives', {
      'project_id': projectId,
      'objective_id': objectiveId,
    }, 'project_id,objective_id');

Future<void> unlinkProjectObjective(String projectId, String objectiveId) =>
    deleteLink('project_objectives', {
      'project_id': projectId,
      'objective_id': objectiveId,
    });

Future<void> linkLabObjective(String labId, String objectiveId) => upsertLink(
  'lab_objectives',
  {'lab_id': labId, 'objective_id': objectiveId},
  'lab_id,objective_id',
);

Future<void> unlinkLabObjective(String labId, String objectiveId) => deleteLink(
  'lab_objectives',
  {'lab_id': labId, 'objective_id': objectiveId},
);

// ------------------------------------------------------- dashboard counters
/// [table] is project_clusters / project_labs; [embed] is clusters / labs.
/// Returns {code: projectCount}. Client-side tally — trivial at this scale.
Future<Map<String, int>> fetchProjectLinkCounts(
  String table,
  String embed,
) async {
  try {
    final rows = await db.from(table).select('$embed(code)');
    final counts = <String, int>{};
    for (final row in rows) {
      final code = (row[embed] as Map<String, dynamic>?)?['code'] as String?;
      if (code != null) {
        counts.update(code, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<int> fetchCount(String table) async {
  try {
    return await db.from(table).count();
  } catch (error) {
    throw Exception(_error(error));
  }
}

/// lab_members rows for a given `year` (distinct persons). Trivial at this scale.
Future<int> countRowsForYear(String table, int year) async {
  try {
    final rows = await db.from(table).select('year').eq('year', year);
    return rows.length;
  } catch (error) {
    throw Exception(_error(error));
  }
}

/// person_roles rows of a given [kind], optionally scoped to [year] (e.g. the
/// mentorship count on the dashboard).
Future<int> countRoles(String kind, {int? year}) async {
  try {
    var request = db.from('person_roles').select('id').eq('kind', kind);
    if (year != null) request = request.eq('year', year);
    final rows = await request;
    return rows.length;
  } catch (error) {
    throw Exception(_error(error));
  }
}

/// Distinct years across every year-bearing table (outputs.reporting_year,
/// lab_members.year, person_roles.year), ascending. Drives the year selectors.
Future<List<int>> fetchDistinctYears() async {
  try {
    final years = <int>{};
    for (final row in await db.from('outputs').select('reporting_year')) {
      final y = row['reporting_year'] as int?;
      if (y != null) years.add(y);
    }
    for (final table in ['lab_members', 'person_roles']) {
      for (final row in await db.from(table).select('year')) {
        final y = row['year'] as int?;
        if (y != null) years.add(y);
      }
    }
    final list = years.toList()..sort();
    return list;
  } catch (error) {
    throw Exception(_error(error));
  }
}

// ------------------------------------------------- person_roles (logbook)
Future<List<Map<String, dynamic>>> fetchPersonRoles(String personId) async {
  try {
    final rows = await db
        .from('person_roles')
        .select('id, kind, label, year, status, notes, link_id')
        .eq('person_id', personId)
        .order('year', ascending: false, nullsFirst: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}

/// Distinct existing labels for a [kind] plus the seed vocabulary — feeds the
/// role/tag autocomplete (a typed new value is still allowed).
Future<List<String>> fetchRoleVocabulary(String kind) async {
  try {
    final rows = await db.from('person_roles').select('label').eq('kind', kind);
    final values = <String>{
      for (final row in rows)
        if ((row['label'] as String?)?.trim().isNotEmpty == true)
          (row['label'] as String).trim(),
    };
    if (kind == 'role') values.addAll(seedRoleVocabulary);
    final list = values.toList()..sort();
    return list;
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> addPersonRole({
  required String personId,
  required String kind,
  required String label,
  int? year,
  String? notes,
  String? linkId,
}) async {
  try {
    await db.from('person_roles').insert({
      'person_id': personId,
      'kind': kind,
      'label': label,
      'year': year,
      'notes': notes,
      'link_id': linkId,
    });
    // Admin adds are approved by the trigger; keep the membership cache in sync.
    await _syncMembershipCache(personId, kind, label, year);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> removePersonRole(String id) async {
  try {
    await db.from('person_roles').delete().eq('id', id);
  } catch (error) {
    throw Exception(_error(error));
  }
}

Future<void> approvePersonRole(String id) async {
  try {
    final row = await db
        .from('person_roles')
        .update({'status': 'approved'})
        .eq('id', id)
        .select('person_id, kind, label, year')
        .maybeSingle();
    if (row != null) {
      await _syncMembershipCache(
        row['person_id'] as String,
        row['kind'] as String,
        row['label'] as String,
        row['year'] as int?,
      );
    }
  } catch (error) {
    throw Exception(_error(error));
  }
}

/// When an admin approves/sets a current-year `membership` entry, mirror it onto
/// `people.membership_type` (the current cache the lists + dashboard read).
Future<void> _syncMembershipCache(
  String personId,
  String kind,
  String label,
  int? year,
) async {
  if (!isAdmin || kind != 'membership' || year != DateTime.now().year) return;
  try {
    await db.from('people').update({'membership_type': label}).eq('id', personId);
  } catch (_) {
    // Cache sync is best-effort; the logbook row is the source of truth.
  }
}

/// Aligns the current-year `membership` logbook row with a scalar edit from the
/// person editor (upsert on the single (person, membership, current-year) row).
Future<void> upsertCurrentMembership(String personId, String label) async {
  final year = DateTime.now().year;
  try {
    final existing = await db
        .from('person_roles')
        .select('id')
        .eq('person_id', personId)
        .eq('kind', 'membership')
        .eq('year', year)
        .maybeSingle();
    if (existing != null) {
      await db
          .from('person_roles')
          .update({'label': label})
          .eq('id', existing['id']);
    } else {
      await db.from('person_roles').insert({
        'person_id': personId,
        'kind': 'membership',
        'label': label,
        'year': year,
      });
    }
  } catch (_) {
    // Best-effort mirror; the scalar people.membership_type is already saved.
  }
}

/// Approved `membership` counts for [year] from the logbook — powers the
/// year-aware dashboard pie. {label: count}.
Future<Map<String, int>> fetchMembershipByYear(int year) async {
  try {
    final rows = await db
        .from('person_roles')
        .select('label')
        .eq('kind', 'membership')
        .eq('status', 'approved')
        .eq('year', year);
    final counts = <String, int>{};
    for (final row in rows) {
      final label = row['label'] as String?;
      if (label != null) counts.update(label, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  } catch (error) {
    throw Exception(_error(error));
  }
}
