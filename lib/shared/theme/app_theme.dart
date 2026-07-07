import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radii.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.canopyGreen,
        primary: AppColors.canopyGreen,
        onPrimary: AppColors.surface,
        secondary: AppColors.umbrellaRed,
        onSecondary: AppColors.surface,
        error: AppColors.umbrellaRed,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          color: AppColors.ink,
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          color: AppColors.ink,
          height: 1.55,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.deepCanopy,
        foregroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.surface,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.surface),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.deepCanopy,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.canopyGreen,
          foregroundColor: AppColors.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 54),
          // NEVER Size(double.infinity, …) here: an infinite minimum width
          // is fatal for any button laid out with unbounded width (e.g. a
          // non-flex child of a Row) — debug throws, release paints NOTHING.
          // This exact line hid the wizard's Continue bar for weeks.
          // Full-width buttons opt in via SizedBox/Expanded at the call site.
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.canopyGreen,
          side: const BorderSide(color: AppColors.canopyGreen, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 54),
          // See elevatedButtonTheme note — infinite minimum width is fatal
          // under unbounded constraints; full width is the call site's job.
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.canopyGreen,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadii.borderSm,
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderSm,
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderSm,
          borderSide: const BorderSide(color: AppColors.canopyGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderSm,
          borderSide: const BorderSide(color: AppColors.umbrellaRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderSm,
          borderSide: const BorderSide(color: AppColors.umbrellaRed, width: 2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.mist),
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.mist),
        errorStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.umbrellaRed),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderMd,
          side: const BorderSide(color: AppColors.hairline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.fillMuted,
        selectedColor: AppColors.canopyGreen,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.borderPill,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.deepCanopy,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.surface,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.canopyGreen,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.canopyGreen : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.greenTint : null,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.canopyGreen,
        foregroundColor: AppColors.surface,
        elevation: 4,
      ),
    );
  }
}
