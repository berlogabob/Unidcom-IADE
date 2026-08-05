import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailBody(
      children: [
        Panel(
          title: 'Centre',
          child: Column(
            children: [
              _detailRow('Unit', 'UNIDCOM/IADE'),
              const SizedBox(height: 12),
              _detailRow('FCT UID', 'UID/00711/2025'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Data & exports',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _linkRow(context, 'Data browser', '/app/admin'),
              const Divider(height: 1),
              _linkRow(context, 'Reports', '/app/admin'),
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

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
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
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
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
