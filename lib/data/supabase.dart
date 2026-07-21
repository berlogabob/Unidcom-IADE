import 'package:supabase_flutter/supabase_flutter.dart';

final db = Supabase.instance.client;

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
          'id, preferred_name, membership_type, status, email, photo_url, profile_status, '
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
