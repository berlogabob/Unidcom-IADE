# Rui's v1.0 acceptance tests (Document 2 §V) — status after Phase D

Source: `RAW_DATA/From_Rui/DOCUMENT 2 -. UNIDCOM RIMS — AI Agent Implementation Specification.docx`, §V.
Legend: **auto** = covered by a unit/widget test on `main`; **code** = implemented, verified by
code review + SQL, needs a live click; **manual** = only a human on the deployed portal can confirm.
Live column: fill in with the researcher test account (`andre.berloga+researcher@`) and an admin.

| # | Acceptance line | How it is met | Evidence | Live |
|---|---|---|---|---|
| **Profile** | | | | |
| 1 | Researcher can edit their profile | code | D4-A #55 owner dialog "Propose changes to my profile" | [ ] |
| 2 | Researcher can save a draft | partial | closing the dialog is the draft; no persisted field-level draft in v1 (PLAN.md D4 decision) | [ ] |
| 3 | Researcher can submit changes | auto | `person_editor_test`: Submit calls the staging function with the changed field | [ ] |
| 4 | Researcher can see review status | auto | `status_strip_test`: "UNIDCOM · Submitted / Approved" | [ ] |
| 5 | Researcher cannot approve their own changes | auto (DB) | `protect_people_cols()` trigger + RLS; D1.3 rollback test; owner dialog never calls `updatePerson` | [ ] |
| **Biography** | | | | |
| 6 | UNIDCOM biography is clearly distinguished from ORCID biography | auto | `bio_compare_test`: two headed columns | [ ] |
| 7 | ORCID differences can be reviewed | auto | same test: differing bios render side by side | [ ] |
| 8 | Importing ORCID does not automatically publish or approve the new biography | code | Import → `proposeMyChanges` (suggestion row), admin accepts; D4-C #56 | [ ] |
| **Outputs** | | | | |
| 9 | Researcher can see their outputs | code | `/app/outputs` → `OwnOutputsSection` (D5-D #60) | [ ] |
| 10 | Researcher can filter by year | auto | `output_filters_test` year; `own_outputs_test` | [ ] |
| 11 | Researcher can filter by type | auto | `output_filters_test` category; taxonomy cascade | [ ] |
| 12 | Researcher can filter by project where applicable | auto | `output_filters_test` projectId; `project_outputs` embed (#57) | [ ] |
| 13 | Researcher can filter by status | auto | `output_filters_test` review / website | [ ] |
| 14 | Researcher can search outputs | auto | `output_filters_test` query; `own_outputs_test` search narrows | [ ] |
| 15 | Researcher can edit outputs | auto | `output_editor_staged_test`: Submit stages changes, never `updateOutput` | [ ] |
| 16 | Researcher can add outputs through the wizard | auto | `output_wizard_test` happy path → `createMyOutput(fields, projectIds)` | [ ] |
| **ORCID** | | | | |
| 17 | Researcher can connect ORCID | code | unchanged: Connect ORCID (broker `orcid-auth`) | [ ] |
| 18 | ORCID records can be imported | code | Add / "Add all unambiguous (n)" → `promote_output_candidate` (#63) | [ ] |
| 19 | Matching is performed using identifiers where available | code | `match_existing_output`: exact DOI first, then trigram title; `find_similar_outputs` | [ ] |
| 20 | Possible duplicates are surfaced | auto | `orcid_buckets_test`: matched_output_id → possibleDuplicate bucket | [ ] |
| 21 | Researcher can mark records "Not mine" | code | Not mine → `reject_output_candidate`; bucket "Not mine · k" | [ ] |
| 22 | ORCID does not automatically overwrite institutional records | auto (DB) | staging table only; weekly script writes `output_candidates`, never `outputs` | [ ] |
| **Featured** | | | | |
| 23 | Researcher can star an output | code | star toggle unchanged; `featured_star.yaml` Maestro flow | [ ] |
| 24 | Maximum of five featured outputs is enforced | auto (DB + UI) | `people_featured_outputs_max` check; `nextFeatured` refuses at cap; header "Featured outputs · N / 5" | [ ] |
| 25 | Featured status does not bypass approval | code | featured is an array on `people`; outputs still need `approval_status = approved` and `website_status = published` | [ ] |
| **Approval** | | | | |
| 26 | Researcher can submit | auto | `create_my_output` forces `pending`; wizard test | [ ] |
| 27 | UNIDCOM approval is distinct from website publication | auto (DB) | `outputs.website_status` (D1) + `WebsitePanel` (#62) + `sync.py` filter check (D10.3) | [ ] |
| 28 | Changes after approval return to the appropriate review state | code | edits are proposals (suggestions) until an admin accepts; the record itself never changes silently | [ ] |
| **Website** | | | | |
| 29 | Researcher cannot publish directly | auto (DB) | `outputs_write` is `is_admin()`; researcher has no path to `website_status` | [ ] |
| 30 | Approved does not automatically mean published | auto | `sync.publication_passes`: approved + not_published → False (D10.3) | [ ] |
| 31 | Website status is visible independently | auto | `status_strip_test` "Website · …"; output row "Website · …" pill | [ ] |
| **UX** | | | | |
| 32 | No unnecessary duplicate navigation | auto | `nav_model_test`: five items, no children (D3) | [ ] |
| 33 | No empty "Coming Soon" pages in the primary navigation | auto | `nav_model_test`: 0 `wip` items in v1 | [ ] |
| 34 | No generic ambiguous "Approved" status | auto | `status_labels_test`; pills always name their dimension ("UNIDCOM · Approved") | [ ] |
| 35 | No "Recent Papers" terminology where multiple output types exist | auto | `grep -rin papers lib test .maestro` = 0 (D2) | [ ] |
| 36 | Membership/role records are not displayed as scientific outputs | auto | `own_outputs_test`: no Membership / Lab · / Role · text on the outputs page (D5) | [ ] |

Counts: 36 lines · auto 22 · code 13 · partial 1 (#2, deliberate: no persisted draft in v1).
