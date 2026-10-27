import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/ds_page.dart';
import '../widgets/panels.dart';
import 'site_content.dart';
import 'website_sync.dart';

/// Admin → More → Website: what the next sync will publish, and the button.
class WebsiteScreen extends StatefulWidget {
  const WebsiteScreen({super.key});

  @override
  State<WebsiteScreen> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends State<WebsiteScreen> {
  late Future<
    ({
      Map<String, dynamic>? last,
      int ready,
      List<Map<String, dynamic>> waiting,
    })
  >
  _data = _load();

  static Future<
    ({
      Map<String, dynamic>? last,
      int ready,
      List<Map<String, dynamic>> waiting,
    })
  >
  _load() async {
    // The sync status needs the edge function + token; the lists must not wait on it.
    Map<String, dynamic>? last;
    try {
      last = await fetchWebsiteSyncStatus();
    } catch (_) {}
    final since = DateTime.tryParse('${last?['started_at']}');
    return (
      last: last,
      ready: (await fetchReadyToPublish()).length,
      waiting: await fetchPublishedSince(since),
    );
  }

  Future<void> _sync() async {
    try {
      await runWebsiteSync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync started. The site updates in a few minutes.'),
        ),
      );
      setState(() => _data = _load());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  final _types = {...sanityTypes};
  bool _pushing = false;

  Future<void> _sanity() async {
    if (_pushing || _types.isEmpty) return;
    setState(() => _pushing = true);
    try {
      final counts = await runSanityPush(
        types: [
          for (final t in sanityTypes)
            if (_types.contains(t)) t,
        ],
      );
      if (!mounted) return;
      final summary = counts.entries
          .map((e) => '${e.value} ${e.key}')
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pushed to the Sanity test project: $summary.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DsPage(
      title: 'Website',
      subtitle:
          'What the next sync puts on the UNIDCOM website. The site syncs by itself every 10 minutes; Publish also starts a sync.',
      children: [
        FutureBuilder(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) return Text('${snap.error}');
            if (!snap.hasData) return const CircularProgressIndicator();
            final d = snap.data!;
            return WebsiteSyncView(
              last: d.last,
              readyCount: d.ready,
              waiting: d.waiting,
              onSync: _sync,
              onOpenReady: () =>
                  context.go('/app/admin/review?tab=readyToPublish'),
            );
          },
        ),
        const SiteContentPanel(),
        Panel(
          title: 'Sync to Sanity (test project)',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sends the portal\'s website content to Sanity. The portal wins on the fields it holds; everything else in Sanity is left alone.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in sanityTypes)
                      FilterChip(
                        label: Text(t),
                        selected: _types.contains(t),
                        onSelected: (on) => setState(
                          () => on ? _types.add(t) : _types.remove(t),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _pushing || _types.isEmpty ? null : _sanity,
                  child: Text(_pushing ? 'Syncing...' : 'Sync to test Sanity'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
