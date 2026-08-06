import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../widgets/panels.dart';

const _affiliationEn =
    'UNIDCOM/IADE, Research Unit in Design and Communication, Oriente Green Campus, Jardim António Augusto Simenta Mordido, 2 – 1885-081 Moscavide, Portugal';
const _affiliationPt =
    'UNIDCOM/IADE, Unidade de Investigação em Design e Comunicação, Oriente Green Campus, Jardim António Augusto Simenta Mordido, 2 – 1885-081 Moscavide, Portugal';
const _fundingEn =
    'This work is supported by FCT — Fundação para a Ciência e Tecnologia, I.P., in the framework of the Project UID/00711/2025 — Research Unit in Design and Communication — UNIDCOM/IADE, with the DOI identifier 10.54499/UID/00711/2025\nDOI: https://doi.org/10.54499/UID/00711/2025';
const _fundingPt =
    'Este trabalho é financiado por fundos nacionais através da FCT — Fundação para a Ciência e a Tecnologia, I.P., no âmbito do projeto UID/00711/2025 — Unidade de Investigação em Design e Comunicação — UNIDCOM/IADE, com o identificador DOI 10.54499/UID/00711/2025\nDOI: https://doi.org/10.54499/UID/00711/2025';
const _signature = '''Name Surname
Role
IADE – Faculty of Design, Technology and Communication, Universidade Europeia
Oriente Green Campus, Jardim António Augusto Simenta Mordido, 2 – 1885-081 Moscavide, Portugal
E email@universidadeeuropeia.pt · iade.europeia.pt
This work is supported by FCT, project UID/00711/2025 – UNIDCOM/IADE (DOI: 10.54499/UID/00711/2025)''';

Widget welcomeSectionBody(BuildContext context, String slug) => switch (slug) {
  'start' => _startSection(),
  'signature' => _signatureSection(context),
  'social' => _socialSection(),
  'docs' => _documentsSection(),
  'conf' => _conferencesSection(),
  'oa' => _openAccessSection(),
  'missions' => _missionsSection(),
  'affiliation' => _affiliationSection(context),
  'report' => _reportSection(),
  'logos' => _logosSection(),
  'contacts' => _contactsSection(),
  _ => const Panel(child: Text('Section not found')),
};

Widget _startSection() => _section(
  title: 'Getting started',
  lead: 'Everything a new UNIDCOM researcher should have at hand.',
  children: [
    _tags([
      'UID/00711/2025',
      'Oriente Green Campus · Moscavide',
      'Design & Communication',
    ]),
    const SizedBox(height: 18),
    _cardGrid([
      _infoCard(
        icon: '👥',
        title: '~40 researchers',
        description:
            'Integrated members, collaborators and PhD students in Design and Communication.',
      ),
      _infoCard(
        icon: '📍',
        title: 'OGC · Moscavide',
        description:
            'Oriente Green Campus, Jardim António Augusto Simenta Mordido, 2 – 1885-081 Moscavide.',
      ),
      _infoCard(
        icon: '🌐',
        title: 'unidcom-iade.pt',
        description:
            'Website, publications, events and information about the research unit.',
      ),
    ]),
    _heading('Your first 5 steps'),
    _steps(const [
      (
        'Set up your email signature',
        'Use the official template with your UNIDCOM/IADE affiliation. See “Email signature”.',
      ),
      (
        'Send your photo and bio to UNIDCOM',
        'For the website: name, role, research area and a professional photo.',
      ),
      (
        'Send your semester activity plan',
        'When requested, include planned conferences, publications and missions. See “Documents & forms”.',
      ),
      (
        'Submit the FPA before any event or publication',
        'The Support Request Form must be filed at least 4 months in advance.',
      ),
      (
        'Always use the correct affiliation and FCT statement',
        'On all papers, presentations and posters. Missing them makes requests ineligible.',
      ),
    ]),
    const SizedBox(height: 18),
    _callout(
      'All support requests require approval from the UNIDCOM Board. Always plan ahead!',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warnDark,
      background: AppColors.amberTintSoft,
    ),
  ],
);

Widget _signatureSection(BuildContext context) => _section(
  title: 'Email signature',
  lead:
      'Official template for your institutional email. Fill in your details and copy it into Outlook.',
  children: [
    const SizedBox(height: 18),
    _callout(
      'Mandatory. Your signature is part of your institutional identity as a UNIDCOM member.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warnDark,
      background: AppColors.amberTintSoft,
    ),
    _heading('Personalise your signature'),
    const _SignatureField(label: 'Full name', hint: 'Name Surname'),
    const SizedBox(height: 12),
    const _SignatureField(label: 'Role', hint: 'e.g. Associate Professor'),
    const SizedBox(height: 12),
    const _SignatureField(label: 'Email', hint: 'name@universidadeeuropeia.pt'),
    const SizedBox(height: 12),
    const _SignatureField(label: 'Mobile (optional)', hint: '+351 …'),
    _heading('Preview'),
    _signaturePreview(context),
    const SizedBox(height: 10),
    const Text(
      'Outlook: File > Options > Mail > Signatures > New > paste the copied content.',
      style: TextStyle(color: AppColors.textFaint, fontSize: 11),
    ),
  ],
);

Widget _signaturePreview(BuildContext context) => Panel(
  padding: const EdgeInsets.all(18),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Name Surname',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Text(
        'Role',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 10),
      Row(children: [_brandTag('IADE', dark: true), _brandTag('UNIDCOM')]),
      const SizedBox(height: 10),
      const Divider(color: AppColors.cardBorder, height: 1),
      const SizedBox(height: 10),
      const SelectableText(
        'IADE – Faculty of Design, Technology and Communication, Universidade Europeia\n'
        'Oriente Green Campus, Jardim António Augusto Simenta Mordido, 2 – 1885-081 Moscavide, Portugal\n'
        'E email@universidadeeuropeia.pt · iade.europeia.pt',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          height: 1.55,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'This work is supported by FCT, project UID/00711/2025 – UNIDCOM/IADE (DOI: 10.54499/UID/00711/2025)',
        style: TextStyle(
          color: AppColors.textFaint,
          fontSize: 10,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: _copyButton(context, _signature),
      ),
    ],
  ),
);

Widget _socialSection() => _section(
  title: 'Social media',
  lead:
      "Follow UNIDCOM and share your publications and appearances to boost the unit's visibility.",
  children: [
    const SizedBox(height: 18),
    _cardGrid([
      _networkCard(
        name: 'Instagram',
        handle: '@unidcom.iade',
        description: 'Events, publications and researcher activity.',
      ),
      _networkCard(
        name: 'Facebook',
        handle: 'UNIDCOM/IADE',
        description: 'News, events and publications from the unit.',
      ),
      _networkCard(
        name: 'LinkedIn',
        handle: 'UNIDCOM/IADE',
        description: 'Projects, researchers and opportunities.',
      ),
    ]),
    _heading('How you can contribute'),
    _checkList(const [
      "Follow all of UNIDCOM's social media channels",
      'When you publish an article or take part in an event, let UNIDCOM know so we can post it',
      "Share UNIDCOM's posts on your personal networks",
      'Send photos of your conference and event participations',
      'If you appear in the media, share the link with UNIDCOM',
    ]),
  ],
);

Widget _documentsSection() => _section(
  title: 'Documents & forms',
  lead:
      'All the documents you need to submit support requests and plan your activities.',
  children: [
    const SizedBox(height: 18),
    _cardGrid([
      _downloadCard(
        icon: '📄',
        title: 'Support Request Form (FPA)',
        description:
            'Fill in and sign before any conference, publication or mission. Mandatory for all financial support requests.',
        download: 'DOCX · request from the secretariat',
      ),
      _downloadCard(
        icon: '📕',
        title: 'Standards & Support Manual',
        description:
            'Complete guide with all rules, support types, eligibility criteria and UNIDCOM procedures for 2026.',
        download: 'PDF · request from the secretariat',
      ),
      _downloadCard(
        icon: '📊',
        title: 'Semester Activity Plan',
        description:
            'Excel table to plan and report your upcoming activities: conferences, publications, missions and projects.',
        download: 'XLSX · request from the secretariat',
      ),
    ]),
    _heading('How to use the Semester Plan'),
    _secondaryLead(
      'The semester plan is requested by UNIDCOM twice a year. You must include:',
    ),
    _checkList(const [
      'Bibliographic output: articles, book chapters, conference participations, posters, supervised theses',
      'Other activities: industry contracts, projects, event organisation, workshops',
      'For each activity: name, budget line (DPD, M, AQ…), date, location, estimated budget and expected outputs',
    ], plain: true),
    const SizedBox(height: 12),
    _callout(
      'Support requests for activities not in the semester plan may not be considered.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warnDark,
      background: AppColors.amberTintSoft,
    ),
    _heading('How to submit the FPA'),
    _steps(const [
      (
        'Download and fill in the FPA',
        'Include all event/publication details, justification and estimated budget.',
      ),
      (
        'Attach the mandatory documents',
        'Event programme, copy of the abstract/paper with affiliation and FCT statement, provisional budget.',
      ),
      (
        'Date and sign the FPA',
        'The form must be dated and signed by the requesting researcher.',
      ),
      (
        'Send it to UNIDCOM by email',
        'UNIDCOM replies within one week with the support decision.',
      ),
    ]),
  ],
);

Widget _conferencesSection() => _section(
  title: 'Conferences & scientific events',
  lead:
      'How to request support to attend conferences, workshops and exhibitions.',
  children: [
    const SizedBox(height: 18),
    _callout(
      'Submit at least 4 months in advance. The FPA must be filed before you send your proposal to the event.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warnDark,
      background: AppColors.amberTintSoft,
    ),
    _heading('Checklist before submitting the FPA'),
    _checkList(const [
      'I am an integrated researcher, or a PhD student co-publishing with an integrated researcher',
      'The event is included in my semester activity plan',
      'I verified the event is not predatory',
      'My participation will generate published, indexed scientific output',
      'I sent the paper/abstract to UNIDCOM before submitting it to the event',
      'The FPA is dated and signed by me',
    ]),
    _heading('Documents to attach to the FPA'),
    _checkList(const [
      'Programme of the international scientific conference/congress',
      'Paper or poster acceptance notification',
      'Copy of the accepted manuscript (with affiliation and FCT statement)',
      'Detailed provisional budget',
    ], plain: true),
    _heading('Payments & invoicing'),
    _secondaryLead(
      'Invoices must be issued to EUROPEIA ID with bank transfer details.',
    ),
    const SizedBox(height: 10),
    _linkRows(const [
      ('Entity', 'EUROPEIA ID'),
      ('NIF', '506 076 547'),
      ('Address', 'Rua Manuel Pinto de Azevedo 748\n4100-320 Porto'),
    ]),
    const SizedBox(height: 18),
    _callout(
      'Credit card, PayPal and Eventbrite are not possible. Pro forma invoices are not accepted.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.red,
      background: AppColors.redTint,
    ),
    _heading('After the event — what to deliver'),
    _checkList(const [
      'Participation certificate',
      'Presentation file (PPT/PDF)',
      'Boarding passes (flights)',
      'Final conference programme',
      'Published paper (when applicable)',
      'Photos of your participation (social media & FCT reporting)',
    ], plain: true),
  ],
);

Widget _openAccessSection() => _section(
  title: 'Open Access publishing',
  lead:
      'Rules for requesting support for publication fees (APC) and revision or translation services.',
  children: [
    const SizedBox(height: 18),
    _callout(
      'Check whether the journal is predatory at predatoryjournals.org and use the Think. Check. Submit. tool.',
      icon: Icons.info_outline,
      color: AppColors.tealDark,
      background: AppColors.tealTint,
    ),
    _heading('Eligible costs'),
    _checkList(const [
      'Scientific translation',
      'Scientific revision',
      'APC fees',
      'Submission fees',
      'Publication fees',
    ]),
    const SizedBox(height: 12),
    _callout(
      'Articles must be in full open access · final publication with a mandatory DOI · payment by bank transfer only.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warnDark,
      background: AppColors.amberTintSoft,
    ),
    _heading('What to deliver to UNIDCOM'),
    _steps(const [
      (
        'Detailed provisional budget',
        'With APC and/or revision/translation costs, before submission.',
      ),
      (
        'Copy of the manuscript',
        'With UNIDCOM affiliation and FCT statement already inserted.',
      ),
      (
        'Invoice (not pro forma)',
        'In the name of Europeia ID, with bank transfer details.',
      ),
      (
        'Final published article',
        'With UNIDCOM affiliation, FCT statement and DOI visible.',
      ),
    ]),
  ],
);

Widget _missionsSection() => _section(
  title: 'Missions',
  lead:
      'Support for travel to coordination and supervision meetings and proposal preparation.',
  children: [
    _heading('Eligible types'),
    _checkList(const [
      'Coordination meetings',
      'Supervision meetings',
      'Scientific organisation',
      'Proposal preparation',
      'Fundraising',
    ]),
    const SizedBox(height: 12),
    _callout(
      'Integrated researchers only · FPA at least 4 months in advance, dated and signed.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warnDark,
      background: AppColors.amberTintSoft,
    ),
    _heading('Documents to attach to the FPA'),
    _checkList(const [
      'Event programme',
      'Official invitation or convocation letter (if applicable)',
      'Acceptance notification (if applicable)',
      'Detailed provisional budget',
    ], plain: true),
    const SizedBox(height: 12),
    _callout(
      'The mission report must be submitted within 15 days of completion.',
      icon: Icons.info_outline,
      color: AppColors.tealDark,
      background: AppColors.tealTint,
    ),
  ],
);

Widget _affiliationSection(BuildContext context) => _section(
  title: 'UNIDCOM affiliation',
  lead:
      'You must include the correct affiliation and the FCT statement in all scientific material.',
  children: [
    const SizedBox(height: 18),
    _callout(
      'A missing affiliation or FCT statement makes the request ineligible and may require funds to be returned.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.red,
      background: AppColors.redTint,
    ),
    _heading('Mandatory affiliation'),
    _secondaryLead('In all papers, chapters, presentations and posters:'),
    const SizedBox(height: 10),
    _copyCard(context, language: 'PT', text: _affiliationPt),
    const SizedBox(height: 12),
    _copyCard(context, language: 'EN', text: _affiliationEn),
    _heading('FCT funding statement'),
    _secondaryLead('Include in the acknowledgements (PT and/or EN):'),
    const SizedBox(height: 10),
    _copyCard(context, language: 'PT', text: _fundingPt),
    const SizedBox(height: 12),
    _copyCard(context, language: 'EN', text: _fundingEn),
  ],
);

Widget _reportSection() => _section(
  title: 'Report activity',
  lead:
      "UNIDCOM's visibility depends on knowing your work. Tell us and we'll share it on social media and report it to FCT.",
  children: [
    const SizedBox(height: 18),
    _callout(
      'Follow UNIDCOM on social media and share your work so we can amplify your research.',
      icon: Icons.info_outline,
      color: AppColors.tealDark,
      background: AppColors.tealTint,
    ),
    _heading('What to tell UNIDCOM'),
    _checkList(const [
      'Publications in scientific journals or books (with DOI/ISBN)',
      'Conference participation — send the abstract/paper before submitting',
      'Media appearances — interviews, op-eds, podcasts…',
      "PhD completion (yours or a supervisee's)",
      'New projects or funding secured',
      'Events you organise or are invited to',
    ]),
    _heading('How to report'),
    _steps(const [
      (
        'Email the UNIDCOM secretariat',
        'With the activity type, date, and a relevant link or file.',
      ),
      (
        'For conferences — send the paper before submitting',
        'We check that the affiliation and FCT statement are correct.',
      ),
      (
        'Share photos and materials from your participation',
        'Used for social media and FCT reports.',
      ),
    ]),
  ],
);

Widget _logosSection() => _section(
  title: 'Logos & brand assets',
  lead:
      'Access and download institutional logos in the correct formats for each context.',
  children: [
    const SizedBox(height: 18),
    _callout(
      'If in doubt about which version to use, contact the UNIDCOM secretariat.',
      icon: Icons.info_outline,
      color: AppColors.tealDark,
      background: AppColors.tealTint,
    ),
    _heading('UNIDCOM/IADE'),
    _logoRow(
      swatch: 'UNIDCOM',
      label: 'Side · Positive',
      format: 'PNG',
      background: AppColors.profileBand,
      foreground: AppColors.cardBg,
    ),
    const SizedBox(height: 10),
    _logoRow(
      swatch: 'UNIDCOM',
      label: 'Side · Negative',
      format: 'PNG',
      background: AppColors.profileBand,
      foreground: AppColors.cardBg,
    ),
    _heading('IADE – Universidade Europeia'),
    _logoRow(
      swatch: 'IADE',
      label: 'Positive',
      format: 'PNG',
      background: AppColors.tealTint,
      foreground: AppColors.tealDark,
    ),
    const SizedBox(height: 10),
    _logoRow(
      swatch: 'IADE',
      label: 'Negative',
      format: 'PNG',
      background: AppColors.profileBand,
      foreground: AppColors.cardBg,
    ),
    _heading('FCT — Fundação para a Ciência e a Tecnologia'),
    _logoRow(
      swatch: 'FCT',
      label: 'Positive · Horizontal',
      format: 'PNG',
      background: AppColors.redTint,
      foreground: AppColors.red,
    ),
    const SizedBox(height: 10),
    _logoRow(
      swatch: 'FCT',
      label: 'Negative · Horizontal',
      format: 'PNG',
      background: AppColors.profileBand,
      foreground: AppColors.cardBg,
    ),
    _heading('Usage rules'),
    _checkList(const [
      'Use the logos in presentations, posters, papers and outreach materials',
      'The research centre logo must sit to the right of the IADE logo, proportionally sized, never larger than the IADE logo rectangle',
      'On dark backgrounds use the negative (white) version; on light backgrounds use the positive (black/colour) version',
      'Do not alter the colours, proportions or typography of the logos',
    ], plain: true),
  ],
);

Widget _contactsSection() => _section(
  title: 'Contacts',
  lead: 'Reach the right team for approvals, admin support and communications.',
  children: [
    const SizedBox(height: 18),
    _cardGrid([
      _contactCard(
        role: 'Scientific coordinator',
        name: 'Hande Ayanoglu, Ph.D.',
        email: 'hande.ayanoglu@iade.pt',
      ),
      _contactCard(
        role: 'Administrative support',
        name: 'UNIDCOM Secretariat',
        email: 'unidcom@iade.pt',
      ),
      _contactCard(
        role: 'Website & communications',
        name: 'UNIDCOM Communications',
        email: 'unidcom.comm@iade.pt',
      ),
    ]),
  ],
);

/// Figma S4: the section title and its lead sit on the page background, with
/// the content cards below them — not inside one enclosing card. The template's
/// per-section eyebrow ("Communication", "Support · DPD") is gone with it: the
/// side nav already names the group, so it was saying the same thing twice.
Widget _section({
  required String title,
  required String lead,
  required List<Widget> children,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 8),
    Text(
      lead,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    ...children,
  ],
);

Widget _heading(String text) => Padding(
  padding: const EdgeInsets.only(top: 24, bottom: 10),
  child: Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  ),
);

Widget _secondaryLead(String text) => Text(
  text,
  style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
);

Widget _tags(List<String> tags) => Padding(
  padding: const EdgeInsets.only(top: 16),
  child: Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final tag in tags)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.sandHoverStrong,
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(AppDims.radiusSm),
          ),
          child: Text(
            tag,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
    ],
  ),
);

Widget _cardGrid(List<Widget> cards) => Wrap(
  spacing: 14,
  runSpacing: 14,
  children: [for (final card in cards) SizedBox(width: 240, child: card)],
);

Widget _infoCard({
  required String icon,
  required String title,
  required String description,
}) => Panel(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 10),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        description,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    ],
  ),
);

Widget _networkCard({
  required String name,
  required String handle,
  required String description,
}) => Panel(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        handle,
        style: const TextStyle(
          color: AppColors.teal,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    ],
  ),
);

// ponytail: No real assets in the repo yet — swap these labels for real
// download links when the secretariat supplies the files.
Widget _downloadCard({
  required String icon,
  required String title,
  required String description,
  required String download,
}) => Panel(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        description,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        download,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
);

Widget _steps(List<(String, String)> steps) => Column(
  children: [
    for (var index = 0; index < steps.length; index++)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.greyTint)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    steps[index].$1,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    steps[index].$2,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
  ],
);

Widget _checkList(List<String> items, {bool plain = false}) => Column(
  children: [
    for (final item in items)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              plain ? Icons.chevron_right : Icons.check_circle_outline,
              size: 16,
              color: AppColors.teal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
  ],
);

Widget _callout(
  String text, {
  required IconData icon,
  required Color color,
  required Color background,
}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(AppDims.radiusSm),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 11),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12.5, height: 1.5),
        ),
      ),
    ],
  ),
);

Widget _linkRows(List<(String, String)> rows) => Panel(
  padding: EdgeInsets.zero,
  child: Column(
    children: [
      for (var index = 0; index < rows.length; index++)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: index == rows.length - 1
              ? null
              : const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rows[index].$1.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              SelectableText(
                rows[index].$2,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

Widget _copyCard(
  BuildContext context, {
  required String language,
  required String text,
}) => Panel(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Figma 45:21 — the language badge and the Copy button share the top
      // row, so the action is found before the block of text, not after it.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.blueTint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              language,
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Spacer(),
          _copyButton(context, text),
        ],
      ),
      const SizedBox(height: 10),
      SelectableText(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ],
  ),
);

/// Figma 45:25 — a filled navy button, not a text link: copying the exact
/// affiliation is the one thing this screen exists to make easy.
Widget _copyButton(BuildContext context, String text, {String label = 'Copy'}) {
  return FilledButton(
    onPressed: () {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied')));
    },
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label),
  );
}

Widget _brandTag(String text, {bool dark = false}) => Padding(
  padding: const EdgeInsets.only(right: 10),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: dark ? AppColors.profileBand : AppColors.tealTint,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: dark ? AppColors.cardBg : AppColors.tealDark,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
);

Widget _logoRow({
  required String swatch,
  required String label,
  required String format,
  required Color background,
  required Color foreground,
}) => Panel(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  child: Row(
    children: [
      Container(
        width: 58,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          swatch,
          style: TextStyle(
            color: foreground,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Text(
        format,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 10),
      const Text('↓', style: TextStyle(color: AppColors.textMuted)),
    ],
  ),
);

Widget _contactCard({
  required String role,
  required String name,
  required String email,
}) => Panel(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        role.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        name,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      Semantics(
        link: true,
        label: 'mailto:$email',
        child: SelectableText(
          email,
          style: const TextStyle(color: AppColors.teal, fontSize: 12),
        ),
      ),
    ],
  ),
);

class _SignatureField extends StatelessWidget {
  const _SignatureField({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
