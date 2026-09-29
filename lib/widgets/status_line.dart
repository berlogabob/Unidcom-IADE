import 'package:flutter/material.dart';
import 'package:unidcom_iade/data/status_labels.dart';
import 'package:unidcom_iade/theme/tokens.dart';

/// Rui 25 Sep: one compact status line at the top of every researcher page.
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

    final statusText =
        'UNIDCOM: ${reviewLabel(profileStatus)} · Website: ${publicVisibility == true ? 'Published' : 'Not published'}';

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
