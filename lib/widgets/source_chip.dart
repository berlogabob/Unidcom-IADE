import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class SourceChip extends StatelessWidget {
  const SourceChip(this.source, {super.key});

  final String? source;

  @override
  Widget build(BuildContext context) {
    if (source == null || source == 'manual') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
      ),
      child: Text(
        'from $source',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
    );
  }
}
