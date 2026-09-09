// Sanity snapshot versus the current Supabase unit. Build: ./build.sh
#import "lib.typ": *
#let d = json("data.json")

#show: report.with((title: "UNIDCOM · Sanity versus Supabase", author: ("UNIDCOM/IADE",), footer: "UNIDCOM · Sanity / Supabase comparison · September 2026", lang: "en"))

#title-block("Sanity versus Supabase", subtitle: "Archive and current unit — merge decision brief", standfirst: [Not a mirror: Sanity = archive to 2023, Supabase = current unit; #d.people.matches of #d.people.sanity_count members are the same people.])
#kpi-row(((d.people.sanity_count, "Sanity members"), (d.people.matches, "Matched people"), ("43 / 33", "Projects · Sanity / DB"), ("1,596 / 365", "Outputs · Sanity / DB")))

= 1. Inventory
#data-table(("Bucket", "Sanity", "Supabase counterpart"), (
  ([Research directory], [#d.inventory.research_sanity], [people #d.inventory.research_supabase.people · projects #d.inventory.research_supabase.projects · outputs #d.inventory.research_supabase.outputs · labs #d.inventory.research_supabase.labs · clusters #d.inventory.research_supabase.clusters]),
  ([Taxonomies], [#d.inventory.taxonomy_sanity], [reference data in current schema]),
  ([Site-editorial and assets], [#d.inventory.editorial_sanity], [none]),
), widths: (4.1cm, 1.7cm, 1fr), right-from: 99)

= 2. People
#data-table(("Match kind", "Count", "Ambiguous"), d.people.match_kinds.pairs().map(((k, v)) => ([#k], [#v], [#if k == "—" {"—"} else {d.people.ambiguous}])), widths: (1fr, 1.6cm, 1.8cm))
#data-table(("Field", "Only Supabase", "Only Sanity", "Both, different (photo: both present)"), d.people.field_diffs.pairs().map(((k, v)) => ([#k], [#v.only_in_supabase], [#v.only_in_sanity], [#v.both_but_different])), widths: (1fr, 2cm, 1.8cm, 1.8cm))
#data-table(("Sanity-only members", "Count", "By member type", "Email · photo · bio"), (
  ([Listed], [#d.people.sanity_only.listed.count], [#d.people.sanity_only.listed.by_member_type], [#d.people.sanity_only.listed.with_email · #d.people.sanity_only.listed.with_photo · #d.people.sanity_only.listed.with_bio]),
  ([Unlisted], [#d.people.sanity_only.unlisted.count], [#d.people.sanity_only.unlisted.by_member_type], [#d.people.sanity_only.unlisted.with_email · #d.people.sanity_only.unlisted.with_photo · #d.people.sanity_only.unlisted.with_bio]),
), widths: (3cm, 1.3cm, 1fr, 2.5cm), right-from: 99)
#data-table(("Supabase-only people", "Count", "Distribution"), (
  ([Current people], [#d.people.supabase_only.count], [status: #d.people.supabase_only.by_status · type: #d.people.supabase_only.by_membership_type]),
), widths: (3cm, 1.3cm, 1fr), right-from: 99)

= 3. Projects & outputs
#data-table(("Measure", "Projects · Sanity", "Projects · Supabase", "Outputs · Sanity", "Outputs · Supabase"), (
  ([Count], [#d.projects.sanity_count], [#d.projects.supabase_count], [#d.outputs.sanity_count], [#d.outputs.supabase_count]),
  ([Years], [#d.projects.sanity_years], [#d.projects.supabase_years], [#d.outputs.sanity_years], [—]),
  ([Status / type], [#d.projects.sanity_status], [#d.projects.supabase_status], [—], [#d.outputs.supabase_macro_type]),
  ([Category / year], [—], [#d.projects.supabase_category], [—], [#d.outputs.supabase_reporting_year]),
  ([Completeness], [funder #d.projects.with_funder · team #d.projects.with_team], [—], [link #d.outputs.with_link · members #d.outputs.with_members], [—]),
  ([Normalised title overlap], [#d.projects.title_overlap], [—], [#d.outputs.title_overlap], [—]),
), widths: (3.1cm, 2.4cm, 2.4cm, 2.4cm, 2.4cm), right-from: 99)
#data-table(("Lab / cluster links", "Sanity-linked", "Total", "Legacy Sanity-only"), (
  ([Labs], [#d.labs_clusters.labs_linked], [#d.labs_clusters.labs_total], [—]),
  ([Clusters], [#d.labs_clusters.clusters_linked], [#d.labs_clusters.clusters_total], [#d.labs_clusters.legacy_clusters]),
), widths: (1fr, 2cm, 1.5cm, 2.3cm))

= 4. Sanity-only content
#data-table(("Sanity type", "Count", "What it is", "Supabase counterpart"), d.editorial.map(x => ([#x.type], [#x.count], [#x.note], [#x.supabase_counterpart])), widths: (3cm, 1.2cm, 1fr, 2.7cm), right-from: 99)

= 5. Decisions this report enables
#data-table(("Decision", "Count", "Default / next action"), (
  ([Link matched people], [#d.decisions.link_matched_people], [apply reviewed links]),
  ([Review ambiguous], [#d.decisions.review_ambiguous], [manual review]),
  ([Import or ignore listed members], [#d.decisions.import_listed_members], [admin decision]),
  ([Sanity-only unlisted], [#d.decisions.ignore_unlisted_members], [default: ignore]),
  ([Legacy projects], [43], [decide later]),
  ([Legacy outputs], [1,596], [stay in Sanity]),
), widths: (1fr, 1.5cm, 3.2cm))
