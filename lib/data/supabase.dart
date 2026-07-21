import 'package:supabase_flutter/supabase_flutter.dart';

final db = Supabase.instance.client;

bool get isAdmin => db.auth.currentUser?.appMetadata['role'] == 'admin';

String _error(Object error) =>
    error is PostgrestException || error is AuthException
    ? (error as dynamic).message as String
    : error.toString();

Future<List<Map<String, dynamic>>> fetchPeople({String? query}) async {
  try {
    final q = query?.trim();
    var request = db
        .from('people')
        .select(
          'id, preferred_name, membership_type, status, email, photo_url, profile_status',
        );
    if (q != null && q.isNotEmpty) {
      request = request.ilike('preferred_name', '%$q%');
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

Future<List<Map<String, dynamic>>> fetchOutputs({
  String? query,
  int? year,
}) async {
  try {
    final q = query?.trim();
    var request = db
        .from('outputs')
        .select(
          'id, title, reporting_year, type, subtype, doi, url, output_authors(people(id,preferred_name))',
        );
    if (q != null && q.isNotEmpty) {
      request = request.ilike('title', '%$q%');
    }
    if (year != null) {
      request = request.eq('reporting_year', year);
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
