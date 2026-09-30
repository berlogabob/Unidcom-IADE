import 'package:flutter/material.dart';

import '../my_profile.dart';

class ScientificOutputsPage extends StatefulWidget {
  const ScientificOutputsPage({super.key, this.personId});

  final String? personId;

  @override
  State<ScientificOutputsPage> createState() => _ScientificOutputsPageState();
}

class _ScientificOutputsPageState extends State<ScientificOutputsPage> {
  @override
  Widget build(BuildContext context) => MyProfileScreen(
    personId: widget.personId,
    section: MySection.outputs,
    framed: true,
  );
}
