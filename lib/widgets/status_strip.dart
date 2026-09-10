import 'package:flutter/material.dart';

import '../app/my_profile.dart';
import '../data/status_labels.dart';
import 'panels.dart';

class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.person,
    required this.pendingCandidates,
  });

  final Map<String, dynamic> person;
  final int pendingCandidates;

  @override
  Widget build(BuildContext context) {
    final connected = (person['orcid'] as String? ?? '').trim().isNotEmpty;
    final changesAvailable = pendingCandidates > 0;
    final status = person['profile_status'] as String?;
    final published =
        status == 'approved' && person['public_visibility'] == true;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusPill(
          'ORCID · ${orcidLabel(connected: connected, changesAvailable: changesAvailable)}',
          tone: !connected
              ? PillTone.grey
              : changesAvailable
              ? PillTone.amber
              : PillTone.teal,
        ),
        StatusPill(
          'UNIDCOM · ${profileStatusLabel(status)}',
          tone: status == 'approved' ? PillTone.teal : PillTone.amber,
        ),
        StatusPill(
          'Website · ${websiteLabel(published ? 'published' : 'not_published')}',
          tone: published ? PillTone.teal : PillTone.grey,
        ),
      ],
    );
  }
}
