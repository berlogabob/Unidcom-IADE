/// Admin statistics computation.
library;


class AdminStats {
  final int integrated;
  final int collaborators;
  final int profilesToApprove;
  final int outputsToApprove;
  final int orcidLinked;
  final int orcidNotLinked;
  final int sitePublished;
  final int siteApprovedNotPublished;
  final int siteNotPublished;
  final int missingDoi;
  final int notOnOrcid;
  final Map<String, int> outputsByType;
  final int outputsTotal;

  const AdminStats({
    required this.integrated,
    required this.collaborators,
    required this.profilesToApprove,
    required this.outputsToApprove,
    required this.orcidLinked,
    required this.orcidNotLinked,
    required this.sitePublished,
    required this.siteApprovedNotPublished,
    required this.siteNotPublished,
    required this.missingDoi,
    required this.notOnOrcid,
    required this.outputsByType,
    required this.outputsTotal,
  });
}

AdminStats computeAdminStats({
  required List<Map<String, dynamic>> people,
  required List<Map<String, dynamic>> outputs,
  required Set<String> orcidOutputIds,
  Set<String> publicationTypes = const {'Artigos em revistas', 'Livros'},
  int? year,
}) {
  // Skip rows whose 'merged_into' is not null
  final filteredPeople = people
      .where((person) => person['merged_into'] == null)
      .toList();
  final filteredOutputs = outputs
      .where((output) => output['merged_into'] == null)
      .toList();

  // Members = people with membership_type 'integrated' or 'collaborator'
  final members = filteredPeople
      .where(
        (person) =>
            person['membership_type'] == 'integrated' ||
            person['membership_type'] == 'collaborator',
      )
      .toList();
  final integrated = members
      .where((person) => person['membership_type'] == 'integrated')
      .length;
  final collaborators = members
      .where((person) => person['membership_type'] == 'collaborator')
      .length;

  // Profiles to approve = members with profile_status 'pending_review'
  final profilesToApprove = members
      .where((person) => const {'pending_review', 'under_review'}.contains(person['profile_status']))
      .length;

  // Outputs to approve = outputs with approval_status 'pending'
  final outputsToApprove = filteredOutputs
      .where((output) => output['approval_status'] == 'pending')
      .length;

  // ORCID counts
  final orcidLinked = members
      .where((person) => person['orcid'] is String && person['orcid'] != '')
      .length;
  final orcidNotLinked = members.length - orcidLinked;

  // Site visibility counts
  final sitePublished = members
      .where((person) => person['public_visibility'] == true)
      .length;
  final siteApprovedNotPublished = members
      .where(
        (person) =>
            person['profile_status'] == 'approved' &&
            person['public_visibility'] != true,
      )
      .length;
  final siteNotPublished =
      members.length - sitePublished - siteApprovedNotPublished;

  // Year filter
  final filteredOutputsForYear = year != null
      ? filteredOutputs.where((output) => output['reporting_year'] == year)
      : filteredOutputs;

  // Outputs by type
  final outputsByType = <String, int>{};
  for (final output in filteredOutputsForYear) {
    final macroType = output['macro_type'] as String?;
    final typeKey = macroType ?? 'Other';
    outputsByType[typeKey] = (outputsByType[typeKey] ?? 0) + 1;
  }

  // Total outputs
  final outputsTotal = filteredOutputsForYear.length;

  // Missing DOI
  final missingDoi = filteredOutputsForYear
      .where(
        (output) =>
            publicationTypes.contains(output['macro_type']) &&
            (output['doi'] == null || output['doi'] == ''),
      )
      .length;

  // Not on ORCID
  final notOnOrcid = filteredOutputsForYear
      .where(
        (output) =>
            publicationTypes.contains(output['macro_type']) &&
            !orcidOutputIds.contains(output['id']) &&
            output['source'] != 'orcid',
      )
      .length;

  return AdminStats(
    integrated: integrated,
    collaborators: collaborators,
    profilesToApprove: profilesToApprove,
    outputsToApprove: outputsToApprove,
    orcidLinked: orcidLinked,
    orcidNotLinked: orcidNotLinked,
    sitePublished: sitePublished,
    siteApprovedNotPublished: siteApprovedNotPublished,
    siteNotPublished: siteNotPublished,
    missingDoi: missingDoi,
    notOnOrcid: notOnOrcid,
    outputsByType: outputsByType,
    outputsTotal: outputsTotal,
  );
}
