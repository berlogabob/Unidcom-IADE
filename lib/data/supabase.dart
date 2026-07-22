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
        .select('id, preferred_name, email, profile_status')
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
        .select('id, title, reporting_year, type, approval_status')
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
        .select('id, preferred_name, email, last_verified_at')
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
        .select('id, title, acronym, description, start_date, end_date, status')
        .order('title');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  } catch (error) {
    throw Exception(_error(error));
  }
}
