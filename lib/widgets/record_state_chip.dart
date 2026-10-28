import 'package:flutter/material.dart';

import 'panels.dart';

class RecordStateChip extends StatelessWidget {
  const RecordStateChip(this.state, {super.key});

  final String state;

  @override
  Widget build(BuildContext context) => StatusPill(
    state,
    tone: switch (state) {
      'On site' => PillTone.teal,
      'Approved' => PillTone.blue,
      'In review' => PillTone.amber,
      _ => PillTone.grey,
    },
  );
}
