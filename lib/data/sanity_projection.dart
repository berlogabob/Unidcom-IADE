Map<String, dynamic> sanityMemberToPerson(
  Map<String, dynamic> doc, {
  String project = 'vj0axykv',
}) {
  final ref = (doc['photo'] as Map?)?['asset'] is Map
      ? ((doc['photo'] as Map)['asset'] as Map)['_ref'] as String?
      : null;
  final match = ref == null
      ? null
      : RegExp(r'^image-([0-9a-f]+)-(\d+x\d+)-([a-z0-9]+)$').firstMatch(ref);
  return {
    'id': doc['_id'],
    'preferred_name': doc['name'],
    'email': doc['email'],
    'orcid': doc['orcid'],
    'ciencia_id': doc['cienciaId'],
    'bio': doc['shortBio'],
    'photo_url': match == null
        ? null
        : 'https://cdn.sanity.io/images/$project/production/${match.group(1)}-${match.group(2)}.${match.group(3)}',
    'status': doc['unlistedFromPeopleList'] == true ? 'inactive' : 'active',
    'membership_type': null,
    'sanity_member_type_ref': (doc['type'] as Map?)?['_ref'],
  };
}
