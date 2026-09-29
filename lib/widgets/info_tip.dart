import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// A widget that displays an info icon with a tooltip on tap.
/// The tooltip shows the provided text when tapped.
class InfoTip extends StatelessWidget {
  /// Creates an InfoTip widget.
  ///
  /// [text] is the text to display in the tooltip.
  /// [size] is the size of the info icon, defaults to 16.
  const InfoTip({super.key, required this.text, this.size = 16});

  /// The text to display in the tooltip.
  final String text;

  /// The size of the info icon.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: const Duration(milliseconds: 300),
      child: Semantics(
        label: 'Info: $text',
        child: Icon(
          Icons.info_outline,
          size: size,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// A widget that wraps a child with an info tip.
///
/// Returns a Row with the child and the info tip.
class WithInfo extends StatelessWidget {
  /// Creates a WithInfo widget.
  ///
  /// [child] is the widget to display next to the info tip.
  /// [info] is the text to display in the tooltip.
  const WithInfo({super.key, required this.child, required this.info});

  /// The widget to display next to the info tip.
  final Widget child;

  /// The text to display in the tooltip.
  final String info;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: child),
        const SizedBox(width: 4),
        InfoTip(text: info),
      ],
    );
  }
}
