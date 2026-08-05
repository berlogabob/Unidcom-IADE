import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

ThemeData unidcomTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.teal,
    onSecondary: Colors.white,
    error: AppColors.red,
    surface: AppColors.cardBg,
    onSurface: AppColors.textPrimary,
    outlineVariant: AppColors.cardBorder,
    onSurfaceVariant: AppColors.textMuted,
  );
  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
  final inter = GoogleFonts.interTextTheme(base.textTheme);
  final smallRadius = BorderRadius.circular(AppDims.radiusSm);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.pageBg,
    textTheme: inter.copyWith(
      bodyMedium: inter.bodyMedium?.copyWith(
        fontSize: 13,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodySmall: inter.bodySmall?.copyWith(
        fontSize: 12,
        color: AppColors.textMuted,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: inter.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
      headlineSmall: inter.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.sidebar,
      foregroundColor: AppColors.textOnDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: AppColors.textOnDark,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.sidebar,
      indicatorColor: AppColors.teal.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.teal
              : AppColors.textOnDarkMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          color: states.contains(WidgetState.selected)
              ? AppColors.teal
              : AppColors.textOnDarkMuted,
          fontSize: 11,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: smallRadius),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: smallRadius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.blue),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: smallRadius,
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: smallRadius,
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
      isDense: true,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.greyTint,
      labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: smallRadius),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorder,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
  );
}
