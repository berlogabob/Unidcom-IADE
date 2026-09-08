import 'package:flutter/material.dart';

import 'welcome_pack_content.dart';

class WelcomePackPage extends StatelessWidget {
  const WelcomePackPage({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          child: welcomeSectionBody(context, section),
        ),
      ),
    );
  }
}
