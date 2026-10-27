import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/supabase.dart';
import '../widgets/ds_page.dart';
import 'website_differences_view.dart';

class WebsiteDifferencesScreen extends StatefulWidget {
  const WebsiteDifferencesScreen({super.key});

  @override
  State<WebsiteDifferencesScreen> createState() =>
      _WebsiteDifferencesScreenState();
}

class _WebsiteDifferencesScreenState extends State<WebsiteDifferencesScreen> {
  List<WebsiteIssue>? _issues;
  bool _loading = false;
  String? _error;

  Future<void> _compare() async {
    if (!isAdmin || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _issues = null;
    });
    try {
      final result = await runSanityPull();
      if (!mounted) return;
      setState(() {
        _issues = [
          for (final issue in result['issues'] as List)
            Map<String, dynamic>.from(issue as Map),
        ];
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String csv) async {
    try {
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV copied for sharing.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not copy CSV: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));
    return DsPage(
      title: 'Website differences',
      subtitle:
          'Compare the live website with all unmerged portal people and outputs. Website-only records need review before adding to the portal. Comparison changes no data.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _loading ? null : _compare,
            child: Text(_loading ? 'Comparing…' : 'Compare with website'),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (_issues != null)
          WebsiteDifferencesView(issues: _issues!, onCopy: _copy),
      ],
    );
  }
}
