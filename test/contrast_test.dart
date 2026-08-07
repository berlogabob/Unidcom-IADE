import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/theme/tokens.dart';

/// WCAG 2.1 relative luminance and contrast ratio.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

// The palette shipped with three tokens below WCAG AA — textMuted at 3.64:1
// while bound to 12px body text in 53 places, textFaint at 2.10:1, and brand
// teal at 2.62:1 carrying the active-tab underline and the spinner. These
// tests exist so a future palette tweak cannot quietly undo that.
void main() {
  const white = AppColors.cardBg;
  const sand = AppColors.pageBg;

  group('body text meets AA (4.5:1) on both light backgrounds', () {
    for (final (name, colour) in <(String, Color)>[
      ('textPrimary', AppColors.textPrimary),
      ('textSecondary', AppColors.textSecondary),
      ('textMuted', AppColors.textMuted),
      ('textFaint', AppColors.textFaint),
    ]) {
      test(name, () {
        expect(contrast(colour, white), greaterThanOrEqualTo(4.5),
            reason: '$name on white');
        expect(contrast(colour, sand), greaterThanOrEqualTo(4.5),
            reason: '$name on the sand page background');
      });
    }
  });

  test('tealDark carries meaning on light backgrounds, brand teal does not', () {
    // Anything a user must perceive — active tab, spinner, progress — uses
    // tealDark. Brand teal stays exactly as Carmela designed it and is only
    // safe on dark or as a fill behind dark text.
    expect(contrast(AppColors.tealDark, white), greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.tealDark, sand), greaterThanOrEqualTo(4.5));
    expect(
      contrast(AppColors.teal, white),
      lessThan(3.0),
      reason: 'if brand teal ever passes on white, the tealDark swaps can be '
          'reverted — until then they must stay',
    );
  });

  test('text on dark chrome meets AA', () {
    expect(contrast(AppColors.textOnDark, AppColors.sidebar),
        greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.textOnDarkMuted, AppColors.sidebar),
        greaterThanOrEqualTo(4.5));
  });

  test('the teal avatar uses dark initials, not white', () {
    // white-on-teal measured 2.62:1; navy-on-teal is 6.60:1.
    expect(contrast(AppColors.profileBand, AppColors.teal),
        greaterThanOrEqualTo(4.5));
    expect(contrast(const Color(0xFFFFFFFF), AppColors.teal), lessThan(4.5));
  });

  test('status tints keep their paired text readable', () {
    for (final (name, fg, bg) in <(String, Color, Color)>[
      ('teal', AppColors.tealDark, AppColors.tealTint),
      ('amber', AppColors.warnDark, AppColors.amberTintSoft),
      ('red', AppColors.red, AppColors.redTint),
      ('blue', AppColors.blue, AppColors.blueTint),
    ]) {
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
    }
  });
}
