/// "Your record" on the Overview (Rui 25 Sep; reworked 1 Oct). The profile
/// loops — approved, edited, reviewed again — so the live version and the
/// current round of changes are two lines, like an app store's "Ready for
/// sale v1" next to "Waiting for review v2".
library;

/// What a step means to the researcher; drives icon and colour.
/// done = green, yours = amber, unidcom = blue, changes = red, todo = grey.
enum StepTone { done, yours, unidcom, changes, todo }

class TimelineStep {
  const TimelineStep(this.label, this.tone, [this.date, this.status = '']);
  final String label;
  final StepTone tone;
  final DateTime? date;
  final String status;

  bool get current =>
      tone == StepTone.yours ||
      tone == StepTone.unidcom ||
      tone == StepTone.changes;
}

class ProfileRecord {
  const ProfileRecord({required this.live, this.round, this.roundStart});

  /// What is on the website now.
  final TimelineStep live;

  /// The current round of changes; null when nothing is pending.
  final List<TimelineStep>? round;
  final DateTime? roundStart;
}

DateTime? _date(Object? value) => DateTime.tryParse(value as String? ?? '');

ProfileRecord profileRecord(Map<String, dynamic> t) {
  final status = t['profile_status'] as String?;
  final visible = t['public_visibility'] == true;
  final approvedAt = _date(t['approved_at']);
  final roundStart = _date(t['round_started_at']) ?? _date(t['created_at']);
  // A date from an older round is not this round's.
  DateTime? inRound(Object? value) {
    final date = _date(value);
    if (date == null) return null;
    if (roundStart != null && date.isBefore(roundStart)) return null;
    return date;
  }

  final live = visible
      ? TimelineStep(
          'Live on the website',
          StepTone.done,
          approvedAt,
          approvedAt == null ? 'Published' : 'Version approved',
        )
      : status == 'approved'
      ? TimelineStep(
          'Approved',
          StepTone.unidcom,
          approvedAt,
          'UNIDCOM publishes it',
        )
      : const TimelineStep(
          'Not on the website yet',
          StepTone.todo,
          null,
          'Published after UNIDCOM approves',
        );

  if (status == 'approved') {
    return ProfileRecord(live: live);
  }

  final drafting =
      status == 'draft' || status == 'to_validate' || status == null;
  final asked = (t['review_note'] as String?)?.trim().isNotEmpty == true;
  final submitted = status == 'pending_review';
  final reviewing = status == 'under_review';
  return ProfileRecord(
    live: live,
    roundStart: roundStart,
    round: [
      TimelineStep(
        'Draft',
        drafting ? (asked ? StepTone.changes : StepTone.yours) : StepTone.done,
        roundStart,
        drafting
            ? (asked
                  ? 'UNIDCOM asked for changes'
                  : 'Your turn · check and submit')
            : 'Done',
      ),
      TimelineStep(
        'Submitted',
        submitted
            ? StepTone.unidcom
            : reviewing
            ? StepTone.done
            : StepTone.todo,
        drafting ? null : inRound(t['submitted_at']),
        submitted
            ? "UNIDCOM's turn"
            : reviewing
            ? 'Done'
            : 'Not yet',
      ),
      TimelineStep(
        'Under review',
        reviewing ? StepTone.unidcom : StepTone.todo,
        reviewing ? inRound(t['review_started_at']) : null,
        reviewing ? "UNIDCOM's turn · reviewing" : 'Not yet',
      ),
      const TimelineStep('Approved', StepTone.todo, null, 'Not yet'),
    ],
  );
}
