// Turns the flat rows from the `report_data` RPC into the JSON contract the Typst
// templates read. Pure — no Deno APIs, no network — so `preview.ts` and `shape_test.ts`
// can run it locally without deploying.
//
// Division of labour: every number that reaches the page is formatted HERE as a string.
// PT-PT decimal commas and phrasings like "20 (19 de 2025 + 1 de 2024)" are business
// rules, not layout. Typst never does arithmetic and never formats a number.

export type Row = {
  id: string;
  title: string | null;
  reporting_year: number | null;
  section: string;
  subsection: string;
  type: string | null;
  category_path: string | null;
  full_reference: string | null;
  doi: string | null;
  url: string | null;
  output_status: string | null;
  approval_status: string | null;
  fct_selected: boolean | null;
  verified_online: boolean | null;
  doi_status: string | null;
  people: string[];
  issues: string[];
};

export type Kind = "outputs" | "activities" | "list" | "review";

/**
 * The report's fixed editorial 1..11 order, titles and intro paragraphs, transcribed
 * from the approved `UNIDCOM_Scientific_Outputs_(2025)__v2.0.pdf`.
 *
 * `db` is the `outputs.macro_type` value; `title` is the shorter heading the report
 * uses. This list — not the database — decides section order and which sections appear,
 * so section 10 still renders with a count of 0 exactly as the approved document does.
 */
export const SECTIONS: { db: string; title: string; intro: string }[] = [
  {
    db: "Livros",
    title: "Livros",
    intro:
      "Reúne a produção editorial do centro — autoria e edição de livros científicos e capítulos (incluindo atas de congresso), com distinção entre outputs indexados (ISI/Scopus) e não indexados. É um dos indicadores centrais de produtividade científica para a FCT.",
  },
  {
    db: "Artigos em revistas",
    title: "Artigos em revistas",
    intro:
      "Artigos publicados em revistas científicas com arbitragem, classificados por quartil (Q1–Q4) e revistas não indexadas. O peso de artigos em quartis superiores (Q1/Q2) é um dos critérios mais valorizados na avaliação FCT.",
  },
  {
    db: "Conferência em congressos (sem publicação)",
    title: "Conferências em congressos (sem publicação)",
    intro:
      "Comunicações orais apresentadas em encontros científicos que não resultaram em publicação em atas. Documentam a disseminação e a presença do centro em fóruns científicos nacionais e internacionais.",
  },
  {
    db: "Organização de Seminários e Conferências",
    title: "Organização de seminários e conferências",
    intro:
      "Participação do centro na organização de eventos científicos — chairs, comissões científicas e comissões organizadoras. Evidencia o papel estruturante e o reconhecimento da unidade na comunidade científica.",
  },
  {
    db: "Formação avançada",
    title: "Formação avançada",
    intro:
      "Contribuição do centro para a formação de novos investigadores — orientações concluídas (mestrado, doutoramento, pós-doutoramento), participação em júris e formação adquirida. As orientações concluídas são um indicador-chave de capacitação para a FCT.",
  },
  {
    db: "Participação em projectos de investigação",
    title: "Participação em projetos de investigação",
    intro:
      "Envolvimento do centro em projetos de investigação nacionais e internacionais, financiados e não financiados, na qualidade de coordenação ou de membro. É um indicador direto de captação de financiamento e de colaboração científica.",
  },
  {
    db: "Reconhecimento pela comunidade científica",
    title: "Reconhecimento pela comunidade científica",
    intro:
      "Distinções, prémios e convites como orador que atestam o impacto e a reputação dos investigadores do centro junto de pares nacionais e internacionais.",
  },
  {
    db: "Missões de internacionalização no âmbito de projetos científicos",
    title: "Missões de internacionalização",
    intro:
      "Deslocações e missões no âmbito de projetos científicos que reforçam a dimensão internacional e as redes de colaboração do centro.",
  },
  {
    db: "Valorizações de atividades ou outros outputs no âmbito de projetos científicos",
    title: "Valorizações de atividades / outros outputs",
    intro:
      "Outputs de valorização e disseminação do conhecimento — exposições, workshops, catálogos e outras iniciativas de ligação à sociedade e ao tecido criativo e cultural.",
  },
  {
    db: "Patentes e contratos industriais",
    title: "Patentes e contratos industriais",
    intro:
      "Propriedade intelectual e contratos com a indústria. A secção é mantida por completude e para monitorização futura, mesmo quando não há registos.",
  },
  {
    db: "Actividades de gestão e auxílio à UNIDCOM",
    title: "Atividades de gestão e auxílio à UNIDCOM",
    intro:
      "Atividades internas de gestão, apoio e promoção da unidade. Têm valor de contexto institucional, mas em geral não constituem output científico para a FCT.",
  },
];

/** Statuses that are listed but excluded from the headline counts, per the FCT criteria. */
const UNCOUNTED = new Set(["Planeado", "Submetido"]);

/** Human labels for the `v_output_issues` codes, used by the ⚠ marker and the appendix. */
const ISSUE_LABELS: Record<string, string> = {
  missing_doi: "sem DOI",
  duplicate: "possível duplicado",
  unverified: "não verificado online",
  invalid_doi: "DOI inválido",
  dead_doi: "DOI inacessível",
  missing_reference: "sem referência completa",
  missing_year: "sem ano",
  implausible_year: "ano implausível",
  missing_type: "sem tipo",
  missing_authors: "sem autores UNIDCOM",
};

const label = (code: string) => ISSUE_LABELS[code] ?? code.replace(/_/g, " ");

/** PT-PT percentage: decimal comma, one decimal place. `0/0` renders as "—". */
export const pct = (n: number, total: number): string =>
  total === 0 ? "—" : `${((n / total) * 100).toFixed(1).replace(".", ",")}%`;

const isCounted = (r: Row) => !UNCOUNTED.has(r.output_status ?? "");

/** Item-level reference entry. Ordering here matches the approved document. */
function toItem(r: Row) {
  const badges: string[] = [];
  const sub = r.subsection ?? "";
  if (/ISI|Scopus/i.test(sub)) badges.push("ISI/Scopus");
  const q = sub.match(/quartil (Q[1-4])/i);
  if (q) badges.push(q[1].toUpperCase());
  if (r.fct_selected) badges.push("FCT");

  const warns = r.issues.map(label);
  const ref = r.full_reference?.trim() || r.title?.trim() || "(sem referência)";
  // Most full_reference strings already end with the DOI or URL. Appending it again
  // printed it twice in the first draft, so only add a link the text doesn't carry.
  const candidate = r.doi ? `https://doi.org/${r.doi}` : r.url || null;
  const already = candidate !== null &&
    (r.doi ? ref.includes(r.doi) : ref.includes(candidate.replace(/^https?:\/\//, "")));

  return {
    ref,
    url: already ? null : candidate,
    // null => render the raw URL so Typst's link line-breaker can split it. Never boxed.
    "url-label": null as string | null,
    isbn: null as string | null,
    badges,
    state: UNCOUNTED.has(r.output_status ?? "") ? r.output_status : null,
    people: r.people ?? [],
    warn: warns.length ? warns.join("; ") : null,
  };
}

function table(columns: string[], rows: string[][], total: string[] | null, title = "Resumo") {
  return {
    title,
    columns,
    rows: rows.map((cells) => ({ cells })),
    total: total ? { cells: total } : null,
  };
}

export function shape(
  rows: Row[],
  opts: { kind: Kind; year: number | null; generatedOn: string; version?: string; toc?: boolean },
) {
  const { kind, year, generatedOn } = opts;
  const version = opts.version ?? "v2.0";
  const scopeYear = year ?? null;
  const yearLabel = scopeYear ? `(${scopeYear})` : "(todos os anos)";

  const counted = rows.filter(isCounted);
  const grandTotal = counted.length;

  // ---- sections -----------------------------------------------------------------
  const bySection = new Map<string, Row[]>();
  for (const r of rows) {
    const arr = bySection.get(r.section) ?? [];
    arr.push(r);
    bySection.set(r.section, arr);
  }

  // Known sections in editorial order, then anything the editorial list doesn't cover
  // (a new macro_type) appended so rows can never silently vanish from the report.
  const known = new Set(SECTIONS.map((s) => s.db));
  const extras = [...bySection.keys()].filter((k) => !known.has(k)).sort();
  const ordered = [
    ...SECTIONS,
    ...extras.map((db) => ({
      db,
      title: db,
      intro: "Secção não prevista na estrutura editorial do relatório; incluída para não omitir registos.",
    })),
  ];

  const sections = ordered.map((meta, i) => {
    const all = bySection.get(meta.db) ?? [];
    const inCount = all.filter(isCounted);

    // Subsections, alphabetical (output_taxonomy is too sparse to order them).
    const bySub = new Map<string, Row[]>();
    for (const r of all) {
      const arr = bySub.get(r.subsection) ?? [];
      arr.push(r);
      bySub.set(r.subsection, arr);
    }
    const subKeys = [...bySub.keys()].sort((a, b) => a.localeCompare(b, "pt"));

    const summaryRows = subKeys.map((k) => {
      const n = (bySub.get(k) ?? []).filter(isCounted).length;
      return [k, String(n), pct(n, inCount.length)];
    });

    // The 🧼 hygiene callout: what was excluded from this section's count, and why.
    const callouts = [];
    const uncounted = all.filter((r) => !isCounted(r));
    const flagged = all.filter((r) => r.issues.length > 0);
    if (uncounted.length || flagged.length) {
      const items = [];
      if (uncounted.length) {
        const byStatus = new Map<string, number>();
        for (const r of uncounted) {
          const s = r.output_status ?? "sem estado";
          byStatus.set(s, (byStatus.get(s) ?? 0) + 1);
        }
        const detail = [...byStatus].map(([s, n]) => `${n} ${s.toLowerCase()}`).join(", ");
        items.push({
          parts: [{
            t: `Dos ${all.length} registos, ${detail} — não contabilizados em ${
              scopeYear ?? "no período"
            }; o total da secção é ${inCount.length}.`,
            url: null,
          }],
        });
      }
      if (flagged.length) {
        items.push({
          parts: [{
            t: `${flagged.length} registo(s) com questões de qualidade assinaladas: ${
              [...new Set(flagged.flatMap((r) => r.issues.map(label)))].join(", ")
            }. Ver o relatório "Revisão de dados" para o detalhe registo a registo.`,
            url: null,
          }],
        });
      }
      callouts.push({ icon: "soap", title: "Tarefas de higienização de dados", items });
    }

    return {
      number: String(i + 1),
      title: meta.title,
      count: inCount.length,
      intro: meta.intro,
      summary: summaryRows.length
        ? table(["Subtipo", "Nº de registos", "% do total"], summaryRows, [
          "Total",
          String(inCount.length),
          inCount.length ? "100%" : "—",
        ])
        : null,
      callouts,
      subsections: subKeys.map((k, j) => {
        const items = bySub.get(k) ?? [];
        const kept = items.filter(isCounted);
        const dropped = items.filter((r) => !isCounted(r));
        const groups = [];
        if (kept.length) groups.push({ label: null, items: kept.map(toItem) });
        if (dropped.length) {
          groups.push({
            label: "Não contabilizados na contagem do período:",
            items: dropped.map(toItem),
          });
        }
        return {
          number: `${i + 1}.${j + 1}`,
          title: k,
          "count-label": dropped.length
            ? `${items.length} (${kept.length} contabilizados + ${dropped.length} não contabilizados)`
            : String(kept.length),
          note: null,
          callouts: [],
          groups,
        };
      }),
    };
  });

  // ---- executive summary --------------------------------------------------------
  const summaryRows = sections
    .filter((s) => s.count > 0 || SECTIONS.some((m) => m.title === s.title))
    .map((s) => [s.title, String(s.count), pct(s.count, grandTotal)]);

  // ---- appendix: reconciliation --------------------------------------------------
  const problem = rows.filter((r) => r.issues.length > 0);
  const appendix = problem.length
    ? {
      title: "Revisão de dados e higienização",
      intro:
        "Consolidação das dúvidas e discrepâncias detetadas na verificação registo a registo. Cada linha identifica o registo e a secção em que foi colocado; a ação sugerida é, em todos os casos, verificar e corrigir o registo na base UNIDCOM.",
      // Three columns, not four: the fourth held the same string on every row. Dropping
      // it and trimming the Registo cell took this table from 541ms to 281ms — the
      // difference between fitting and blowing the Edge worker's resource limit.
      table: table(
        ["Registo", "Secção", "Discrepância / dúvida"],
        problem.slice(0, 200).map((r) => [
          (r.title ?? r.full_reference ?? r.id).slice(0, 80),
          r.section,
          r.issues.map(label).join("; "),
        ]),
        null,
        "Tabela de revisão (dúvidas e discrepâncias)",
      ),
      blocks: [{
        title: "Registos não contabilizados",
        intro:
          "Registos presentes na base e listados no relatório, mas excluídos das contagens do período por estado (planeado/submetido).",
        items: rows.filter((r) => !isCounted(r)).map((r) => ({
          parts: [{
            t: `${(r.title ?? r.full_reference ?? r.id).slice(0, 120)} — ${r.output_status} (${r.section})`,
            url: null,
          }],
        })),
      }],
    }
    : null;

  const flaggedCount = problem.length;
  const isReview = kind === "review";
  const docTitle = isReview ? "UNIDCOM — Revisão de dados" : "UNIDCOM Scientific Outputs";
  return {
    kind,
    meta: {
      title: docTitle,
      subtitle: `${yearLabel} — ${version}`,
      footer: `${docTitle} ${yearLabel} — ${version}`,
      scope: isReview
        ? "Documento de apoio à higienização da base UNIDCOM. Lista, registo a registo, as discrepâncias detetadas automaticamente e os registos excluídos das contagens do período. Acompanha o relatório de produção científica, que reporta as mesmas questões de forma agregada por secção."
        : "Documento estruturado ao nível do Centro de Investigação (não é um relatório por investigador). Cada tipo de output é sumarizado e, em seguida, listado. A contagem corresponde ao número de outputs de cada tipo. Para cada output apresenta-se a referência (APA quando disponível; caso contrário, a referência completa disponível), com indicação do(s) investigador(es) UNIDCOM associado(s).",
      "notes-title": "Notas metodológicas",
      notes: [
        `Âmbito: outputs de ${
          scopeYear ?? "todos os anos"
        } concluídos/publicados. Outputs planeados/submetidos são apresentados em separado e não entram na contagem.`,
        `Os valores são gerados diretamente da base UNIDCOM. Foram assinalados ${flaggedCount} registo(s) com questões de qualidade que podem ainda alterar ligeiramente os totais.`,
      ],
      "source-note": `Fonte: base UNIDCOM | Outputs. Dados a ${generatedOn}.`,
      lang: "pt",
      region: "PT",
      // Off by default: the approved reference document has no table of contents, and
      // `outline()` forces extra introspection layout passes that measured at 418ms of
      // a 695ms compile — enough to push a cold Edge worker over WORKER_RESOURCE_LIMIT.
      // Pass `toc: true` in the request body when a long report warrants one.
      "show-toc": opts.toc === true,
    },
    summary: kind === "list" || isReview ? null : {
      // title/columns/rows/total come from table() below; only `intro` is extra.
      intro:
        "Visão global da produção científica da UNIDCOM, agregada por tipo de output. Os totais refletem outputs concluídos ou publicados no período; outputs planeados ou submetidos são reportados em separado e não entram na contagem, em linha com os critérios de reporte da FCT.",
      ...table(
        ["Tipo de output", "Nº de outputs", "% do total"],
        summaryRows,
        ["Total", String(grandTotal), grandTotal ? "100%" : "—"],
        `Sumário executivo ${yearLabel}`,
      ),
    },
    // `list` reuses the identical shape: one section, one subsection, one flat group —
    // so outputs.typ renders it with no branching.
    // `review` is appendix-only: the reconciliation tables, no outputs listing.
    sections: isReview ? [] : kind === "list"
      ? [{
        number: "1",
        title: "Registos",
        count: grandTotal,
        intro: "Listagem dos registos correspondentes aos filtros selecionados.",
        summary: null,
        callouts: [],
        subsections: [{
          number: "1.1",
          title: "Resultados",
          "count-label": String(rows.length),
          note: null,
          callouts: [],
          groups: [{ label: null, items: rows.map(toItem) }],
        }],
      }]
      : sections,
    // Appendix lives in its own report kind, not inside `outputs`. Bundling the two
    // made a 28-page document that tipped the Edge worker's resource limit ~40% of the
    // time; split, both render reliably. The per-section hygiene callouts stay in
    // `outputs`, so nothing is lost — the record-by-record reconciliation just gets
    // its own document.
    appendix: isReview ? appendix : null,
  };
}
