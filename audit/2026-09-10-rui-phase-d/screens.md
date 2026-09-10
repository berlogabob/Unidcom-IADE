# Screen inventory

Crawler: Playwright/Chromium 1280×900 (phone rows 390×844). Build: `flutter build web --dart-define=E2E=true` (v1), commit 5c4cb7c, served from build/web on :8123.

| Screen | Mode | How reached | Files | Note |
|---|---|---|---|---|
| state_loading_cold | anon | cold load, screenshot at +250 ms | screens/state_loading_cold.png · hierarchy/state_loading_cold.json | ST-LOAD evidence |
| login | anon | openLink #/login | screens/login.png · hierarchy/login.json |  |
| anon_welcome_start | anon | openLink #/app/welcome/start | screens/anon_welcome_start.png · hierarchy/anon_welcome_start.json |  |
| anon_welcome_affiliation | anon | openLink #/app/welcome/affiliation | screens/anon_welcome_affiliation.png · hierarchy/anon_welcome_affiliation.json |  |
| anon_welcome_fct | anon | openLink #/app/welcome/fct | screens/anon_welcome_fct.png · hierarchy/anon_welcome_fct.json |  |
| anon_welcome_report | anon | openLink #/app/welcome/report | screens/anon_welcome_report.png · hierarchy/anon_welcome_report.json |  |
| anon_welcome_signature | anon | openLink #/app/welcome/signature | screens/anon_welcome_signature.png · hierarchy/anon_welcome_signature.json |  |
| anon_welcome_social | anon | openLink #/app/welcome/social | screens/anon_welcome_social.png · hierarchy/anon_welcome_social.json |  |
| anon_welcome_logos | anon | openLink #/app/welcome/logos | screens/anon_welcome_logos.png · hierarchy/anon_welcome_logos.json |  |
| anon_welcome_contacts | anon | openLink #/app/welcome/contacts | screens/anon_welcome_contacts.png · hierarchy/anon_welcome_contacts.json |  |
| anon_deeplink_people | anon | openLink #/people | screens/anon_deeplink_people.png · hierarchy/anon_deeplink_people.json | expected: bounced to /login |
| anon_welcome_docs_m2 | anon | openLink #/app/welcome/docs | screens/anon_welcome_docs_m2.png · hierarchy/anon_welcome_docs_m2.json | M2 slug: expected redirect to start |
| state_login_error | anon | login with wrong password | screens/state_login_error.png · hierarchy/state_login_error.json | ST-ERROR evidence |
| mode_chooser | signed-in | after Sign in | screens/mode_chooser.png · hierarchy/mode_chooser.json |  |
| r_landing_after_choose | researcher | chooser → As a researcher | screens/r_landing_after_choose.png · hierarchy/r_landing_after_choose.json |  |
| r_home | researcher | openLink #/app/home | screens/r_home.png · hierarchy/r_home.json |  |
| r_home_summary | researcher | openLink #/app/home/summary | screens/r_home_summary.png · hierarchy/r_home_summary.json |  |
| r_home_recent | researcher | openLink #/app/home/recent | screens/r_home_recent.png · hierarchy/r_home_recent.json |  |
| r_home_alerts | researcher | openLink #/app/home/alerts | screens/r_home_alerts.png · hierarchy/r_home_alerts.json |  |
| r_home_status | researcher | openLink #/app/home/status | screens/r_home_status.png · hierarchy/r_home_status.json |  |
| r_profile | researcher | openLink #/app/profile | screens/r_profile.png · hierarchy/r_profile.json |  |
| r_profile_identifiers | researcher | openLink #/app/profile/identifiers | screens/r_profile_identifiers.png · hierarchy/r_profile_identifiers.json |  |
| r_profile_bio | researcher | openLink #/app/profile/bio | screens/r_profile_bio.png · hierarchy/r_profile_bio.json |  |
| r_profile_areas_wip | researcher | openLink #/app/profile/areas | screens/r_profile_areas_wip.png · hierarchy/r_profile_areas_wip.json |  |
| r_profile_interests_wip | researcher | openLink #/app/profile/interests | screens/r_profile_interests_wip.png · hierarchy/r_profile_interests_wip.json |  |
| r_profile_status | researcher | openLink #/app/profile/status | screens/r_profile_status.png · hierarchy/r_profile_status.json |  |
| r_outputs | researcher | openLink #/app/outputs | screens/r_outputs.png · hierarchy/r_outputs.json |  |
| r_outputs_add | researcher | openLink #/app/outputs/add | screens/r_outputs_add.png · hierarchy/r_outputs_add.json |  |
| r_outputs_edit_wip | researcher | openLink #/app/outputs/edit | screens/r_outputs_edit_wip.png · hierarchy/r_outputs_edit_wip.json |  |
| r_outputs_import | researcher | openLink #/app/outputs/import | screens/r_outputs_import.png · hierarchy/r_outputs_import.json |  |
| r_outputs_validation_wip | researcher | openLink #/app/outputs/validation | screens/r_outputs_validation_wip.png · hierarchy/r_outputs_validation_wip.json |  |
| r_welcome_start | researcher | openLink #/app/welcome/start | screens/r_welcome_start.png · hierarchy/r_welcome_start.json |  |
| r_welcome_affiliation | researcher | openLink #/app/welcome/affiliation | screens/r_welcome_affiliation.png · hierarchy/r_welcome_affiliation.json |  |
| r_welcome_fct | researcher | openLink #/app/welcome/fct | screens/r_welcome_fct.png · hierarchy/r_welcome_fct.json |  |
| r_welcome_report | researcher | openLink #/app/welcome/report | screens/r_welcome_report.png · hierarchy/r_welcome_report.json |  |
| r_welcome_signature | researcher | openLink #/app/welcome/signature | screens/r_welcome_signature.png · hierarchy/r_welcome_signature.json |  |
| r_welcome_social | researcher | openLink #/app/welcome/social | screens/r_welcome_social.png · hierarchy/r_welcome_social.json |  |
| r_welcome_logos | researcher | openLink #/app/welcome/logos | screens/r_welcome_logos.png · hierarchy/r_welcome_logos.json |  |
| r_welcome_contacts | researcher | openLink #/app/welcome/contacts | screens/r_welcome_contacts.png · hierarchy/r_welcome_contacts.json |  |
| r_help_links | researcher | openLink #/app/help/links | screens/r_help_links.png · hierarchy/r_help_links.json |  |
| r_help_docs_wip | researcher | openLink #/app/help/docs | screens/r_help_docs_wip.png · hierarchy/r_help_docs_wip.json |  |
| r_help_faq_wip | researcher | openLink #/app/help/faq | screens/r_help_faq_wip.png · hierarchy/r_help_faq_wip.json |  |
| r_settings | researcher | openLink #/app/settings | screens/r_settings.png · hierarchy/r_settings.json |  |
| r_deeplink_people | researcher | openLink #/people | screens/r_deeplink_people.png · hierarchy/r_deeplink_people.json | expected: bounced to /app/home |
| r_deeplink_requests_v2 | researcher | openLink #/app/requests | screens/r_deeplink_requests_v2.png · hierarchy/r_deeplink_requests_v2.json | v2 route: expected bounce |
| r_unknown_route | researcher | openLink #/nope/404 | screens/r_unknown_route.png · hierarchy/r_unknown_route.json | unknown route |
| r_profile_edit_dialog | researcher | /app/profile → Edit | screens/r_profile_edit_dialog.png · hierarchy/r_profile_edit_dialog.json |  |
| r_add_output_dialog | researcher | /app/outputs/add → Add output | screens/r_add_output_dialog.png · hierarchy/r_add_output_dialog.json |  |
| r_sidebar_expanded | researcher | /app/home default sidebar | screens/r_sidebar_expanded.png · hierarchy/r_sidebar_expanded.json |  |
| r_account_menu | researcher | sidebar footer: Switch to admin / Public site / Sign out (not clicked) | screens/r_account_menu.png · hierarchy/r_account_menu.json |  |
| phone_r_home | researcher (390px) | openLink #/app/home | screens/phone_r_home.png · hierarchy/phone_r_home.json |  |
| phone_r_profile | researcher (390px) | openLink #/app/profile | screens/phone_r_profile.png · hierarchy/phone_r_profile.json |  |
| phone_r_outputs | researcher (390px) | openLink #/app/outputs | screens/phone_r_outputs.png · hierarchy/phone_r_outputs.json |  |
| a_landing_after_choose | admin | chooser → As an administrator | screens/a_landing_after_choose.png · hierarchy/a_landing_after_choose.json |  |
| a_dashboard | admin | openLink #/app/dashboard | screens/a_dashboard.png · hierarchy/a_dashboard.json |  |
| a_people | admin | openLink #/people | screens/a_people.png · hierarchy/a_people.json |  |
| a_person | admin | openLink #/people/4f09781a-c469-5368-91aa-50c6b0ec0648 | screens/a_person.png · hierarchy/a_person.json |  |
| a_person_e2e_self | admin | openLink #/people/64e46dd8-0e57-4e6c-8560-b1f4f4d83415 | screens/a_person_e2e_self.png · hierarchy/a_person_e2e_self.json |  |
| a_outputs | admin | openLink #/outputs | screens/a_outputs.png · hierarchy/a_outputs.json |  |
| a_output | admin | openLink #/outputs/08e00845-05f7-5d99-b73d-e5b5812c50c4 | screens/a_output.png · hierarchy/a_output.json |  |
| a_projects | admin | openLink #/projects | screens/a_projects.png · hierarchy/a_projects.json |  |
| a_project | admin | openLink #/projects/ce19906d-11e7-5213-92ec-54deb067fab5 | screens/a_project.png · hierarchy/a_project.json |  |
| a_conferences | admin | openLink #/conferences | screens/a_conferences.png · hierarchy/a_conferences.json |  |
| a_structure | admin | openLink #/structure | screens/a_structure.png · hierarchy/a_structure.json |  |
| a_lab | admin | openLink #/labs/e9e4427a-d634-5dc7-bfa7-225da992076e | screens/a_lab.png · hierarchy/a_lab.json |  |
| a_cluster | admin | openLink #/clusters/ed43a144-9f44-5fde-8730-a208f5779d6e | screens/a_cluster.png · hierarchy/a_cluster.json |  |
| a_objective | admin | openLink #/objectives/ac0befd5-67ce-57c2-9eaf-29635b749a75 | screens/a_objective.png · hierarchy/a_objective.json |  |
| a_admin_review | admin | openLink #/app/admin/review | screens/a_admin_review.png · hierarchy/a_admin_review.json |  |
| a_admin_merge | admin | openLink #/app/admin/merge | screens/a_admin_merge.png · hierarchy/a_admin_merge.json |  |
| a_admin_reports | admin | openLink #/app/admin/reports | screens/a_admin_reports.png · hierarchy/a_admin_reports.json |  |
| a_admin_data | admin | openLink #/app/admin/data | screens/a_admin_data.png · hierarchy/a_admin_data.json |  |
| a_settings | admin | openLink #/app/settings | screens/a_settings.png · hierarchy/a_settings.json |  |
| a_admin_requests_v2 | admin | openLink #/app/admin/requests | screens/a_admin_requests_v2.png · hierarchy/a_admin_requests_v2.json | v2 route: expected redirect |
| a_deeplink_profile | admin | openLink #/app/profile | screens/a_deeplink_profile.png · hierarchy/a_deeplink_profile.json | researcher route in admin mode |
| state_empty_people_search | admin | /people → search 'zzqxv-nomatch' | screens/state_empty_people_search.png · hierarchy/state_empty_people_search.json | ST-EMPTY evidence |
| phone_a_dashboard | admin (390px) | openLink #/app/dashboard | screens/phone_a_dashboard.png · hierarchy/phone_a_dashboard.json |  |
| phone_a_people | admin (390px) | openLink #/people | screens/phone_a_people.png · hierarchy/phone_a_people.json |  |
| phone_a_person | admin (390px) | openLink #/people/4f09781a-c469-5368-91aa-50c6b0ec0648 | screens/phone_a_person.png · hierarchy/phone_a_person.json |  |
| phone_a_review | admin (390px) | openLink #/app/admin/review | screens/phone_a_review.png · hierarchy/phone_a_review.json |  |
| state_error_backend_down | admin | /people with supabase blocked | screens/state_error_backend_down.png · hierarchy/state_error_backend_down.json | ST-ERROR evidence |
| state_error_dashboard_down | admin | /app/dashboard with supabase blocked | screens/state_error_dashboard_down.png · hierarchy/state_error_dashboard_down.json | ST-ERROR evidence |

## NOT COVERED

- ORCID OAuth sign-in (third-party login; not automatable safely).
- v2-only surfaces (Support requests, Approve/Auto-fill/ORCID sync buttons) — compiled out of the pilot build.
- Research Areas / Interests / Edit outputs / Validation / Documentation / FAQs render the shared WipPage.
