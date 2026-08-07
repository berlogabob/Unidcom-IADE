import 'package:flutter/material.dart';

/// Design tokens from RAW_DATA/TemplatesFromCarmela (admin + researcher templates).
abstract final class AppColors {
  // Structure
  static const sidebar = Color(0xFF0E1525);      // --sidebar-bg / --topnav-bg
  static const profileBand = Color(0xFF101A30);  // --profile-bg
  static const pageBg = Color(0xFFF5F4F0);       // --page-bg (sand)
  static const cardBg = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE2E1DC);
  static const sandHover = Color(0xFFFAF9F5);
  static const sandHoverStrong = Color(0xFFF0EFE9);

  // Text
  static const textPrimary = Color(0xFF16213A);
  static const textSecondary = Color(0xFF444240);
  // Darkened 2026-08-07 to clear WCAG AA. The Figma values (#888680 / #B4B3B0)
  // measured 3.64:1 and 2.10:1 on white and worse on the sand page background,
  // against a 4.5:1 requirement — and textMuted is bound to bodySmall at 12px,
  // the strictest case, in 53 places.
  //
  // Both now pass, which necessarily compresses the scale: a three-level grey
  // on white can only span 4.5:1 to 21:1. Muted and faint are close in
  // lightness now, so lean on size and weight for hierarchy, not on lightness.
  static const textMuted = Color(0xFF6A6862); // 5.57:1 white / 5.06:1 sand
  static const textFaint = Color(0xFF706E68); // 5.10:1 white / 4.63:1 sand
  static const textOnDark = Color(0xFFEEF1F6);
  static const textOnDarkMuted = Color(0xFF8A94A8);

  // Semantic
  // Brand teal, from Carmela's Figma — left exactly as designed. It measures
  // 2.62:1 on white, so it must not carry meaning on its own: anything a user
  // has to *perceive* (an active tab underline, a spinner) uses tealDark.
  static const teal = Color(0xFF00B49B);
  static const tealDark = Color(0xFF0A7A68);     // 5.25:1 — text and UI on light
  static const amber = Color(0xFFF5A622);
  static const amberDark = Color(0xFF8A5A08);    // text on amber tint
  static const warn = Color(0xFFD49522);
  static const warnDark = Color(0xFF894F00);
  static const red = Color(0xFFCC2B2B);
  static const blue = Color(0xFF2B68B8);
  static const purple = Color(0xFF7B3F9E);
  static const orange = Color(0xFFE8622A);
  static const navy = Color(0xFF16213A);
  static const green = Color(0xFF2E7D32);

  // Alert dots
  static const alertWarnDot = Color(0xFFD49522);
  static const alertDangerDot = Color(0xFFDB6565);
  static const alertInfoDot = Color(0xFF2B68B8);

  // Pill / badge background tints
  static const tealTint = Color(0xFFE6F6F2);
  static const amberTint = Color(0xFFFDF0DC);
  static const amberTintSoft = Color(0xFFFFF3DE);
  static const greyTint = Color(0xFFEFEEEA);
  static const redTint = Color(0xFFFDEAEA);
  static const blueTint = Color(0xFFE5EEFB);
  static const greenTint = Color(0xFFE4F5E8);
  static const purpleTint = Color(0xFFECEAFB);
}

abstract final class AppDims {
  static const radius = 10.0;
  static const radiusSm = 6.0;
  static const shadowCard = [
    BoxShadow(color: Color(0x0A10152A), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0810152A), offset: Offset(0, 1), blurRadius: 3),
  ];
}
