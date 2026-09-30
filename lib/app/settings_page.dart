import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/tokens.dart';
import '../widgets/ds_page.dart';
import '../widgets/panels.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DsPage(
      title: 'Settings',
      subtitle: 'Your account and the admin tools.',
      children: [
        Panel(
          title: 'Centre',
          child: Column(
            children: [
              _detailRow(context, 'Unit', 'UNIDCOM/IADE'),
              const SizedBox(height: 12),
              _detailRow(context, 'FCT UID', 'UID/00711/2025'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Data & exports',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _linkRow(context, 'Data browser', '/app/admin/data'),
              const Divider(height: 1),
              _linkRow(context, 'Reports', '/app/admin/reports'),
              const Divider(height: 1),
              _linkRow(context, 'CSV export', '/outputs'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Session',
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/people');
              },
              child: const Text('Sign out'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _linkRow(BuildContext context, String label, String path) {
    return InkWell(
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
