import 'package:flutter/material.dart';
import 'package:unidcom_iade/data/status_labels.dart';
import 'package:unidcom_iade/theme/tokens.dart';

/// Bumped after the researcher submits, so the shell reloads the line (G-3).
final statusLineRefresh = ValueNotifier<int>(0);

String memberLabel(String? type) => switch (type) {
  'integrated' => 'Integrated researcher',
  'collaborator' => 'Collaborator',
  'phd_student' => 'PhD student',
  'external' => 'External researcher',
  'advisory_board' => 'Advisory board',
  'staff' => 'Staff',
  _ => 'Researcher',
};

/// Rui 25 Sep + v1.0 brief G-3: one compact status line at the top of every
/// researcher page — "Name · type   UNIDCOM: … · Website: …".
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.person});

  final Map<String, dynamic>? person;

  @override
  Widget build(BuildContext context) {
    if (person == null) {
      return Container();
    }

    final profileStatus = person!['profile_status'] as String?;
    final publicVisibility = person!['public_visibility'] as bool?;

    final name = (person!['preferred_name'] as String?)?.trim() ?? '';
    final who = name.isEmpty
        ? ''
        : '$name · ${memberLabel(person!['membership_type'] as String?)}  ·  ';
    final statusText =
        '${who}UNIDCOM: ${reviewLabel(profileStatus)} · Website: ${publicVisibility == true ? 'Published' : 'Not published'}';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.pageBg,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        statusText,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        semanticsLabel: 'Record status: $statusText',
      ),
    );
  }
}
