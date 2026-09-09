import 'package:flutter/material.dart';

import 'data_page.dart';
import 'merge.dart';
import 'reports.dart';
import 'review_queue.dart';
import 'sanity_merge.dart';

/// The tools /app/admin/:tool can show. Anything else redirects to review.
const adminTools = ['reports', 'review', 'merge', 'sanity', 'data'];

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.tool});

  final String tool;

  @override
  Widget build(BuildContext context) {
    return switch (tool) {
      'reports' => const ReportsScreen(),
      'merge' => const MergeScreen(),
      'sanity' => const SanityMergeScreen(),
      'data' => const DataScreen(),
      _ => const ReviewQueueScreen(),
    };
  }
}
