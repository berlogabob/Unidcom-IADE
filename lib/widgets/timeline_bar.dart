import 'package:flutter/material.dart';
import '../data/timeline.dart' as timeline;
import '../theme/tokens.dart';

/// Rui 25 Sep (B2·4): dated profile timeline on the Overview.
class TimelineBar extends StatelessWidget {
  const TimelineBar({super.key, required this.steps});

  final List<timeline.TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
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

    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: steps.map((step) {
        final icon = step.state == timeline.StepState.done
            ? Icons.check_circle
            : step.state == timeline.StepState.current
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked;

        final iconColor = step.state == timeline.StepState.todo
            ? AppColors.textMuted
            : step.state == timeline.StepState.current
            ? AppColors.tealDark
            : AppColors.teal;

        final labelText = step.state == timeline.StepState.done
            ? 'done'
            : step.state == timeline.StepState.current
            ? 'in progress'
            : 'not yet';

        final dateText =
            step.date != null && step.state != timeline.StepState.todo
            ? '${step.date!.day} ${months[step.date!.month - 1]} ${step.date!.year}'
            : (step.state == timeline.StepState.current ? 'In progress' : '—');

        final current = step.state == timeline.StepState.current;
        return Semantics(
          label: '${step.label}, $labelText',
          child: Container(
            key: ValueKey(
              current ? 'timeline-step-current' : 'timeline-step-${step.label}',
            ),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: current ? AppColors.tealTint : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.label,
                      style: TextStyle(
                        fontWeight: current
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      step.status,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      dateText,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
