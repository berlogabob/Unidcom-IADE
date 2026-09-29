/// Rui 25 Sep: the profile timeline on the Overview (Draft → Submitted → Under review → Published, dated).
enum StepState { done, current, todo }

class TimelineStep {
  const TimelineStep(this.label, this.state, [this.date]);
  final String label;
  final StepState state;
  final DateTime? date;
}

List<TimelineStep> profileTimeline(Map<String, dynamic> t) {
  final status = t['profile_status'];
  final visible = t['public_visibility'] == true;
  return [
    TimelineStep(
      'Draft',
      status == 'to_validate' || status == 'draft'
          ? StepState.current
          : StepState.done,
      DateTime.tryParse(t['created_at'] as String? ?? ''),
    ),
    TimelineStep(
      'Submitted',
      status == 'pending_review'
          ? StepState.current
          : status == 'under_review' || status == 'approved'
          ? StepState.done
          : StepState.todo,
      DateTime.tryParse(t['submitted_at'] as String? ?? ''),
    ),
    TimelineStep(
      'Under review',
      status == 'under_review'
          ? StepState.current
          : status == 'approved'
          ? StepState.done
          : StepState.todo,
      DateTime.tryParse(
        t[status == 'approved' ? 'approved_at' : 'review_started_at']
                as String? ??
            '',
      ),
    ),
    TimelineStep(
      'Published',
      visible
          ? StepState.done
          : (status == 'approved' ? StepState.current : StepState.todo),
      DateTime.tryParse(t['published_at'] as String? ?? ''),
    ),
  ];
}
