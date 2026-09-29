import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'info_tip.dart';

/// Rui 25 Sep (B3·3, A3·3): ORCID on My Profile — import only in v1.0.
class OrcidBlock extends StatelessWidget {
  const OrcidBlock({
    super.key,
    required this.connected,
    this.lastImported,
    this.busy = false,
    required this.onImport,
    required this.onConnect,
  });

  final bool connected;
  final DateTime? lastImported;
  final bool busy;
  final VoidCallback onImport;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (connected)
            Text(
              'ORCID connected · ${lastImported == null ? 'Not imported yet' : 'Last imported ${_formatDate(lastImported!)}'}',
            )
          else
            Text('ORCID not connected'),
          if (connected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onImport,
                  child: const Text('Import from ORCID'),
                ),
                const SizedBox(width: 4),
                const InfoTip(
                  text: 'Copies your ORCID data into a proposal for UNIDCOM review. Nothing changes on ORCID.',
                ),
              ],
            ),
          if (connected)
            Text(
              'Editing here does not change your ORCID record.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          if (!connected)
            OutlinedButton(
              onPressed: onConnect,
              child: const Text('Connect ORCID'),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
