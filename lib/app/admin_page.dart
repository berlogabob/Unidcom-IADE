import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'data_page.dart';
import 'merge.dart';
import 'reports.dart';
import 'review_queue.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const ColoredBox(
            color: AppColors.cardBg,
            child: TabBar(
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.teal,
              dividerColor: AppColors.cardBorder,
              tabs: [
                Tab(text: 'Reports'),
                Tab(text: 'Review'),
                Tab(text: 'Merge'),
                Tab(text: 'Data'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ReportsScreen(),
                ReviewQueueScreen(),
                MergeScreen(),
                DataScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
