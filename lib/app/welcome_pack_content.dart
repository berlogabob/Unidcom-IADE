import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/panels.dart';

Widget welcomeSectionBody(BuildContext context, String slug) {
  final title = switch (slug) {
    'start' => 'Welcome Pack 2026',
    'signature' => 'Email signature',
    'social' => 'Social media',
    'docs' => 'Documents & forms',
    'conf' => 'Conferences',
    'oa' => 'Open Access',
    'missions' => 'Missions',
    'affiliation' => 'Affiliation statement',
    'report' => 'Report activity',
    'logos' => 'Logos & brand',
    'contacts' => 'Contacts',
    _ => 'Section not found',
  };

  return Panel(
    title: title,
    child: Text(
      'Content coming in T4.3/T4.4',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
    ),
  );
}
