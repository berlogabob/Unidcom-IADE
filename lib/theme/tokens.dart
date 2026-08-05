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
  static const textMuted = Color(0xFF888680);
  static const textFaint = Color(0xFFB4B3B0);
  static const textOnDark = Color(0xFFEEF1F6);
  static const textOnDarkMuted = Color(0xFF8A94A8);

  // Semantic
  static const teal = Color(0xFF00B49B);
  static const tealDark = Color(0xFF0A7A68);     // text on teal tint
  static const amber = Color(0xFFEA9522);
  static const amberDark = Color(0xFF8A5A08);    // text on amber tint
  static const warn = Color(0xFFD49522);
  static const warnDark = Color(0xFF894F00);
  static const red = Color(0xFFB71C1C);
  static const blue = Color(0xFF16449E);
  static const purple = Color(0xFF59299E);
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
