import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/ds_page.dart';
import 'site_content.dart';
import 'website_sync.dart';

/// Admin → More → Website: sync status, differences and recovery.
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
          'Publish sends updates to the website and Sanity. The website also syncs every 10 minutes; check its status and retry here if needed.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => context.go('/app/admin/website-differences'),
            child: const Text('Website differences'),
          ),
        ),
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
      ],
    );
  }
}
