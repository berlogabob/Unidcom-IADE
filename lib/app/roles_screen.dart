import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart' show showSnack;
import '../widgets/ds_page.dart';
import '../widgets/panels.dart';

/// Admin → Roles: the role × permission matrix and who holds which role.
/// Every write goes through an RPC that checks roles.manage server-side; this
/// screen only draws. Accounts are still created in the Supabase dashboard.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late Future<(RolesMatrix, List<Map<String, dynamic>>)> _data = _load();

  static Future<(RolesMatrix, List<Map<String, dynamic>>)> _load() async =>
      (await fetchRolesMatrix(), await fetchAccounts());

  void _reload() => setState(() => _data = _load());

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) showSnack(context, '$error');
    }
    _reload();
  }

  Future<void> _newRole() async {
    final key = TextEditingController();
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name, e.g. Publications editor',
              ),
            ),
            TextField(
              controller: key,
              decoration: const InputDecoration(
                labelText: 'Key',
                helperText: 'lowercase letters, digits, _ (e.g. pub_editor)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok == true && key.text.trim().isNotEmpty) {
      await _run(
        () => saveRole(
          key.text.trim(),
          label.text.trim().isEmpty ? key.text.trim() : label.text.trim(),
          {},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPerm('roles.manage')) {
      return const Center(child: Text('Admin access required'));
    }
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (matrix, accounts) = snap.data!;
        return DsPage(
          title: 'Roles',
          subtitle:
              'Tick what each role may do, then give people a role. Changes apply on their next page load. '
              'New accounts are created in the Supabase dashboard; they appear below after their first sign-in.',
          action: FilledButton(
            onPressed: _newRole,
            child: const Text('New role'),
          ),
          children: [_matrix(matrix), _accounts(matrix, accounts)],
        );
      },
    );
  }

  Widget _matrix(RolesMatrix m) => Panel(
    title: 'Permissions',
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Permission')),
          for (final r in m.roles)
            DataColumn(
              label: Row(
                children: [
                  Text('${r['label']}'),
                  if (r['builtin'] != true)
                    IconButton(
                      tooltip: 'Delete role ${r['label']}',
                      iconSize: 16,
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          _run(() => deleteRole(r['key'] as String)),
                    ),
                ],
              ),
            ),
        ],
        rows: [
          for (final p in m.permissions)
            DataRow(
              cells: [
                DataCell(
                  Tooltip(
                    message: '${p['description']}',
                    child: Text('${p['description']}'),
                  ),
                ),
                for (final r in m.roles) _cell(m, r, p['key'] as String),
              ],
            ),
        ],
      ),
    ),
  );

  DataCell _cell(RolesMatrix m, Map<String, dynamic> role, String perm) {
    final key = role['key'] as String;
    final granted = m.grants[key] ?? <String>{};
    // Locked so nobody can lock everybody out of this page.
    final locked = key == 'admin' && perm == 'roles.manage';
    return DataCell(
      Checkbox(
        value: granted.contains(perm),
        onChanged: locked
            ? null
            : (on) => _run(
                () => saveRole(
                  key,
                  role['label'] as String,
                  on == true
                      ? {...granted, perm}
                      : ({...granted}..remove(perm)),
                ),
              ),
      ),
    );
  }

  Widget _accounts(RolesMatrix m, List<Map<String, dynamic>> accounts) => Panel(
    title: 'Accounts',
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Person')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Last sign-in')),
        ],
        rows: [
          for (final a in accounts)
            DataRow(
              cells: [
                DataCell(Text('${a['person_name'] ?? '—'}')),
                DataCell(Text('${a['email'] ?? ''}')),
                DataCell(
                  DropdownButton<String?>(
                    value: a['role_key'] as String?,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Researcher (no role)'),
                      ),
                      for (final r in m.roles)
                        DropdownMenuItem(
                          value: r['key'] as String,
                          child: Text('${r['label']}'),
                        ),
                    ],
                    onChanged: (role) =>
                        _run(() => setUserRole(a['user_id'] as String, role)),
                  ),
                ),
                DataCell(
                  Text(
                    '${a['last_sign_in_at'] ?? 'never'}'
                        .split('.')
                        .first
                        .replaceFirst('T', ' '),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
