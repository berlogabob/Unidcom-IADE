import 'package:flutter/material.dart';

import '../data/timeline.dart';
import '../theme/tokens.dart';
import 'suggestion_tile.dart' show dayLabel;

/// "Your record": what is live on the website, then the current round of
/// changes (if any). Colour always comes with an icon and words.
class TimelineBar extends StatelessWidget {
  const TimelineBar({super.key, required this.record});

  final ProfileRecord record;

  @override
  Widget build(BuildContext context) {
    final live = record.live;
    final round = record.round;
    final (liveIcon, liveColor, _) = _style(live.tone);
    final liveText = [
      live.label,
      if (live.date != null)
        '${live.status} ${dayLabel(live.date!.toLocal())}'
      else
        live.status,
      if (round == null && live.tone == StepTone.done) 'No pending changes',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Website: $liveText',
          excludeSemantics: true,
          child: Row(
            key: const ValueKey('timeline-live'),
            children: [
              Icon(liveIcon, size: 18, color: liveColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  liveText,
                  style: TextStyle(
                    color: liveColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (round != null) ...[
          const SizedBox(height: 16),
          Text(
            [
              'Changes in progress',
              if (record.roundStart != null)
                'started ${dayLabel(record.roundStart!.toLocal())}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final step in round) _step(step)],
          ),
        ],
      ],
    );
  }

  Widget _step(TimelineStep step) {
    final (icon, color, tint) = _style(step.tone);
    final date = step.date == null ? '—' : dayLabel(step.date!.toLocal());
    return Semantics(
      label: '${step.label}, ${step.status}, $date',
      excludeSemantics: true,
      child: Container(
        key: ValueKey(
          step.current
              ? 'timeline-step-current'
              : 'timeline-step-${step.label}',
        ),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: step.current ? tint : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step.label,
                  style: TextStyle(
                    fontWeight: step.current
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                Text(
                  step.status,
                  style: TextStyle(
                    fontSize: 12,
                    color: step.current ? color : AppColors.textSecondary,
                    fontWeight: step.current ? FontWeight.w600 : null,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Icon, foreground (text-safe) and tint per tone.
  static (IconData, Color, Color) _style(StepTone tone) => switch (tone) {
    StepTone.done => (
      Icons.check_circle,
      AppColors.tealDark,
      AppColors.tealTint,
    ),
    StepTone.yours => (
      Icons.edit_note,
      AppColors.amberDark,
      AppColors.amberTint,
    ),
    StepTone.unidcom => (
      Icons.hourglass_top,
      AppColors.blue,
      AppColors.blueTint,
    ),
    StepTone.changes => (Icons.error_outline, AppColors.red, AppColors.redTint),
    StepTone.todo => (
      Icons.radio_button_unchecked,
      AppColors.textMuted,
      AppColors.sandHover,
    ),
  };
}
