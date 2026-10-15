import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  /// Display face used for hero / brand moments only.
  static TextStyle display({double size = 32, Color color = AppColors.ink}) =>
      GoogleFonts.prata(fontSize: size, height: 1.15, color: color);

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.ink,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.ink,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          error: AppColors.danger,
          surfaceTint: Colors.transparent,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );
    final text = GoogleFonts.outfitTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.ink);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.muted),
        border: border(AppColors.line),
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.ink, 1.5),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.accent,
        textColor: Colors.white,
      ),
    );
  }
}
