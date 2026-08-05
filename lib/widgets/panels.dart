import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum AccentTone { good, warn, urgent, neutral, info }

enum PillTone { teal, amber, grey, red, blue, green, purple }

const _cardDecoration = BoxDecoration(
  color: AppColors.cardBg,
  border: Border.fromBorderSide(BorderSide(color: AppColors.cardBorder)),
  borderRadius: BorderRadius.all(Radius.circular(AppDims.radius)),
  boxShadow: AppDims.shadowCard,
);

extension on AccentTone {
  Color get color => switch (this) {
    AccentTone.good => AppColors.teal,
    AccentTone.warn => AppColors.amber,
    AccentTone.urgent => AppColors.red,
    AccentTone.neutral => AppColors.textFaint,
    AccentTone.info => AppColors.blue,
  };
}

extension on PillTone {
  (Color, Color) get colors => switch (this) {
    PillTone.teal => (AppColors.tealTint, AppColors.tealDark),
    PillTone.amber => (AppColors.amberTint, AppColors.amberDark),
    PillTone.grey => (AppColors.greyTint, AppColors.textMuted),
    PillTone.red => (AppColors.redTint, AppColors.red),
    PillTone.blue => (AppColors.blueTint, AppColors.blue),
    PillTone.green => (AppColors.greenTint, AppColors.green),
    PillTone.purple => (AppColors.purpleTint, AppColors.purple),
  };
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class AccentStatCard extends StatelessWidget {
  const AccentStatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.tone = AccentTone.neutral,
  });

  final String label;
  final String value;
  final String? sub;
  final AccentTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(height: 3, child: ColoredBox(color: tone.color)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.tone = PillTone.grey});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = tone.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge(this.text, {super.key, this.tone = PillTone.grey});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = tone.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class FilterPill extends StatelessWidget {
  const FilterPill(
    this.text, {
    super.key,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(999));
    return Material(
      color: selected ? AppColors.navy : AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: selected ? AppColors.navy : AppColors.cardBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        hoverColor: selected ? AppColors.navy : AppColors.sandHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? AppColors.cardBg : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
