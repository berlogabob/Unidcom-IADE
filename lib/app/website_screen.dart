import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/ds_page.dart';
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
      ],
    );
  }
}
