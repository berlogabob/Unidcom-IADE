import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../csv_download.dart';
import '../../data/enrich_client.dart';
import '../../data/supabase.dart';
import '../../public/person/featured_outputs.dart';
import '../../theme/tokens.dart';
import '../../widgets/detail_scaffold.dart';
import 'my_profile_view.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key, this.personId});

  final String? personId;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  late final Future<_ProfileData> _data = _load();

  Future<_ProfileData> _load() async {
    final person = widget.personId == null
        ? await fetchMyPerson()
        : await fetchPerson(widget.personId!);
    if (person == null) throw Exception('No researcher profile found');
    final full = widget.personId == null
        ? await fetchPerson(person['id'] as String)
        : person;
    final labRows = (full['lab_members'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .where((row) => row['labs'] is Map)
        .map((row) {
          final lab = row['labs'] as Map;
          return [lab['code'], lab['name']]
              .where((value) => value != null && '$value'.trim().isNotEmpty)
              .join(' — ');
        })
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    final ids = featuredOf(full);
    final authors = (full['output_authors'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .where((row) {
          final output = row['outputs'];
          return output is Map &&
              (output['affiliation'] ?? 'unidcom') == 'unidcom';
        })
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final outputs = [
      for (final id in ids)
        for (final author in authors)
          if (outputIdOf(author) == id)
            if (author['outputs'] is Map)
              Map<String, dynamic>.from(author['outputs'] as Map),
    ];
    final orcid = await fetchOrcidValues(full['id'] as String);
    return _ProfileData(full, labRows, outputs, orcid);
  }

  // G-5: ORCID is import-only; "Connect ORCID" links the account (orcid-auth).
  Future<void> _connectOrcid() async {
    try {
      final url = await startOrcidLink('${Uri.base.origin}${Uri.base.path}');
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ProfileData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const ColoredBox(
          color: AppColors.pageBg,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return Center(child: Text(snapshot.error.toString()));
      }
      final data = snapshot.data!;
      final id = data.person['id'] as String;
      final readOnly = widget.personId != null;
      return MyProfileView(
        person: data.person,
        labs: data.labs,
        featured: data.featured,
        orcid: data.orcid,
        readOnly: readOnly,
        onSaveDraft: (proposed) =>
            saveMyDraft(id, _current(data.person), proposed),
        onSubmit: (proposed) async {
          await proposeMyChanges(id, _current(data.person), proposed);
          await submitMyDrafts(id);
          final status = data.person['profile_status'];
          if (status == 'draft' || status == 'to_validate') {
            await submitMyProfileForReview(id);
          }
        },
        onConnectOrcid: _connectOrcid,
        onUploadPhoto: () async {
          final file = await pickImageFile();
          if (file == null) return;
          try {
            await proposeMyPhoto(id, data.person['photo_url'] as String?, file);
            if (context.mounted) {
              showSnack(context, 'Photo sent for UNIDCOM review');
            }
          } catch (error) {
            if (context.mounted) showSnack(context, error.toString());
          }
        },
        onManageFeatured: () => context.go('/app/outputs?view=featured'),
      );
    },
  );

  Map<String, String?> _current(Map<String, dynamic> person) => {
    for (final key in ['preferred_name', 'ciencia_id', 'email', 'bio'])
      key: person[key] as String?,
  };
}

class _ProfileData {
  const _ProfileData(this.person, this.labs, this.featured, this.orcid);

  final Map<String, dynamic> person;
  final List<String> labs;
  final List<Map<String, dynamic>> featured;
  final Map<String, String>? orcid;
}
