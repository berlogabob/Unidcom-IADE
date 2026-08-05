/// Status vocabulary and transition rules for `support_requests`, shared by
/// the owner-facing form and the admin review list. Pure helpers — no
/// Supabase/Flutter imports — so RLS-mirrored logic here is easy to unit test.
const requestStatuses = ['draft', 'submitted', 'approved', 'rejected', 'completed'];

/// True while the owner may still edit the request (matches the RLS policy).
bool ownerCanEdit(String status) => status == 'draft' || status == 'submitted';

/// True when the owner may submit the request for review (draft only).
bool ownerCanSubmit(String status) => status == 'draft';

/// Statuses an admin may move [status] to next; empty once the request has
/// left the review pipeline (rejected/completed, or an unknown status).
List<String> adminNextStatuses(String status) => switch (status) {
  'submitted' => ['approved', 'rejected'],
  'approved' => ['completed', 'rejected'],
  _ => [],
};
