import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'info_tip.dart';
import 'panels.dart';

/// The one page frame every v1 page uses (Rui's target layouts, 25 Sep; style
/// from Carmela's screens): sand background, a title card, then blocks — each
/// block a [Panel] — separated by [dsGap]. Nothing else sets page padding,
/// width or the title style.
const dsGap = 16.0;

class DsPage extends StatelessWidget {
  const DsPage({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material, not ColoredBox: ListTiles in blocks need a Material ancestor.
    return Material(
      color: AppColors.pageBg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DsTitleCard(title: title, subtitle: subtitle, action: action),
              for (final child in children) ...[
                const SizedBox(height: dsGap),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Page title block: title, one explanatory line, optional action on the right.
class DsTitleCard extends StatelessWidget {
  const DsTitleCard({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 16), action!],
        ],
      ),
    );
  }
}

/// Two blocks side by side on wide screens (equal height), stacked on phones.
class DsRow extends StatelessWidget {
  const DsRow({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: dsGap),
              right,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: leftFlex, child: left),
              const SizedBox(width: dsGap),
              Expanded(flex: rightFlex, child: right),
            ],
          ),
        );
      },
    );
  }
}

/// A labelled value line inside a block: "Ciência ID (i)   E018-7F41-627B".
class DsField extends StatelessWidget {
  const DsField({
    super.key,
    required this.label,
    required this.child,
    this.info,
  });

  final String label;
  final Widget child;
  final String? info;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(width: 4),
                  InfoTip(text: info!, size: 14),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// N blocks in one row, equal width and height on wide screens; stacked on
/// phones. Same call shape as Wrap(spacing:, runSpacing:, children:).
class DsGrid extends StatelessWidget {
  const DsGrid({
    super.key,
    required this.children,
    this.spacing = dsGap,
    this.runSpacing = dsGap,
    this.minWidth = 760,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                children[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}
