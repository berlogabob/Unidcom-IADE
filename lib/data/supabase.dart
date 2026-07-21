import 'package:supabase_flutter/supabase_flutter.dart';

final db = Supabase.instance.client;

Future<List<Map<String, dynamic>>> fetchPeople() {
  return db.from('people').select();
}
