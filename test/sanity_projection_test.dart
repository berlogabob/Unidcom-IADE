import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/sanity_projection.dart';

void main() {
  test('maps a complete member and photo reference', () {
    final person = sanityMemberToPerson({
      '_id': 'member-1',
      'name': 'Ada',
      'email': 'ada@example.com',
      'orcid': '0000',
      'cienciaId': 'ci',
      'shortBio': 'Bio',
      'photo': {
        'asset': {'_ref': 'image-ab12-800x600-jpg'},
      },
      'type': {'_ref': 'memberType-1'},
    });
    expect(person, containsPair('id', 'member-1'));
    expect(
      person['photo_url'],
      'https://cdn.sanity.io/images/vj0axykv/production/ab12-800x600.jpg',
    );
    expect(person['sanity_member_type_ref'], 'memberType-1');
  });

  test('maps absent photo and type to null', () {
    final person = sanityMemberToPerson({'_id': 'member-2', 'name': 'Bea'});
    expect(person['photo_url'], isNull);
    expect(person['sanity_member_type_ref'], isNull);
    expect(person['membership_type'], isNull);
  });

  test('maps unlisted members inactive', () {
    expect(
      sanityMemberToPerson({
        '_id': 'member-3',
        'unlistedFromPeopleList': true,
      })['status'],
      'inactive',
    );
  });

  test('tolerates a list-valued type reference', () {
    // One real member document carries `type` as a one-element list.
    final person = sanityMemberToPerson({
      '_id': 'member-4',
      'name': 'Cy',
      'type': [{'_ref': 'memberType-9', '_type': 'reference'}],
    });
    expect(person['sanity_member_type_ref'], 'memberType-9');
  });
}
