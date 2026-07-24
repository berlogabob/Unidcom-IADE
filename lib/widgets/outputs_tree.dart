import 'package:flutter/material.dart';

import '../data/supabase.dart';

/// A node in the output taxonomy tree.
class TreeNode {
  TreeNode(this.label);
  final String label;
  final List<TreeNode> children = [];
}

/// Folds `output_taxonomy` rows (each a materialized `segments` path + a
/// `sort_order`) into a nested tree, deriving intermediate nodes from shared
/// prefixes. Child order follows sort_order, then first appearance.
List<TreeNode> buildTree(List<Map<String, dynamic>> rows) {
  final sorted = [...rows]
    ..sort(
      (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
        b['sort_order'] as int? ?? 0,
      ),
    );
  final roots = <TreeNode>[];
  for (final row in sorted) {
    final segments = (row['segments'] as List? ?? const [])
        .map((s) => '$s')
        .where((s) => s.isNotEmpty)
        .toList();
    var siblings = roots;
    for (final label in segments) {
      var node = siblings.cast<TreeNode?>().firstWhere(
        (n) => n!.label == label,
        orElse: () => null,
      );
      if (node == null) {
        node = TreeNode(label);
        siblings.add(node);
      }
      siblings = node.children;
    }
  }
  return roots;
}

/// Read-only, collapsible view of the director's output taxonomy.
class OutputsTree extends StatelessWidget {
  const OutputsTree({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchTable('output_taxonomy'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final roots = buildTree(snapshot.data ?? const []);
        if (roots.isEmpty) return const Center(child: Text('No taxonomy rows'));
        return ListView(
          children: [for (final node in roots) _node(context, node)],
        );
      },
    );
  }

  Widget _node(BuildContext context, TreeNode node) {
    if (node.children.isEmpty) {
      return ListTile(
        dense: true,
        leading: const Icon(Icons.circle, size: 8),
        title: Text(node.label),
      );
    }
    return ExpansionTile(
      title: Text(node.label),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: [for (final child in node.children) _node(context, child)],
    );
  }
}
