import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/supabase.dart';

Map<String, dynamic> person(String name) => {'id': name, 'preferred_name': name};

void main() {
  test('distinct middle names are NOT grouped', () {
    final groups = groupMergeCandidates([
      person('Paulo Teixeira Costa'),
      person('Paulo Nuno Costa'),
    ]);
    expect(groups, isEmpty);
  });

  test('subset names ARE grouped', () {
    final groups = groupMergeCandidates([
      person('Sara Gancho'),
      person('Sara Patrícia Martins Gancho'),
    ]);
    expect(groups, hasLength(1));
    expect(groups.first, hasLength(2));
  });

  test('unrelated names are not grouped', () {
    final groups = groupMergeCandidates([
      person('Ana Silva'),
      person('Bruno Costa'),
    ]);
    expect(groups, isEmpty);
  });
}
