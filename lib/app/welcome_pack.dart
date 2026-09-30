import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'welcome_pack_content.dart';

class WelcomePackPage extends StatelessWidget {
  const WelcomePackPage({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    // DsPage's frame: sand background, 1100 wide, 24 padding.
    return Material(
      color: AppColors.pageBg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: welcomeSectionBody(context, section),
          ),
        ),
      ),
    );
  }
}
