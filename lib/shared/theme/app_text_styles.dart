import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// Type scale: Display 32/38/700/-0.5 · H1 24/30/700/-0.3 · H2 20/26/600/-0.2
//             Title 17/24/600/0 · Body 15/22/400/0 · Label 13/18/500/0.1
//             Caption 12/16/500/0.2
//
// Statecraft type — LOCKED (VANGUARD_REBUILD_V2.md §C0):
// Display/headings/numbers → Sora (600/700)
// Body/UI/identifiers      → Plus Jakarta Sans
// Scale: Display 28/34 · H1 22/28 · H2 17/24 · Body 15/22 · Caption 12.5/18

class AppTextStyles {
  // ── Display ───────────────────────────────────────────────────────────────
  static TextStyle display({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
        height: 34 / 28,
      );

  static TextStyle displayLarge({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.0,
        height: 1.1,
      );

  // ── Eyebrow (small all-caps label above display headings) ────────────────
  static TextStyle eyebrow({Color color = AppColors.mist}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 1.5,
        height: 1.4,
      );

  // ── Headings ──────────────────────────────────────────────────────────────
  static TextStyle h1({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
        height: 28 / 22,
      );

  static TextStyle h2({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
        height: 24 / 17,
      );

  static TextStyle h3({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0,
        height: 24 / 17,
      );

  // ── UI / body ─────────────────────────────────────────────────────────────
  static TextStyle title({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        height: 24 / 17,
      );

  static TextStyle body({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        height: 22 / 15,
      );

  static TextStyle bodyLarge({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.6,
      );

  static TextStyle bodyMedium({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color,
        height: 22 / 15,
      );

  static TextStyle label({Color color = AppColors.mist}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
        height: 18 / 13,
      );

  static TextStyle caption({Color color = AppColors.mist}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.2,
        height: 18 / 12.5,
      );

  static TextStyle small({Color color = AppColors.mist}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  // ── Identifiers (tabular / mono) ──────────────────────────────────────────
  static TextStyle memberNumber({Color color = AppColors.canopyGreen}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle timestamp({Color color = AppColors.mist}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle statNumber({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle statNumberLg({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── App bar & buttons ─────────────────────────────────────────────────────
  static TextStyle appBarTitle({Color color = AppColors.surface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle buttonText({Color color = AppColors.surface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.1,
      );

  static TextStyle badge({Color color = AppColors.surface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.3,
      );

  // ── Specialised tokens ────────────────────────────────────────────────────
  static TextStyle navLabel({Color color = AppColors.mist}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
        height: 1.3,
      );

  static TextStyle navLabelActive({Color color = AppColors.canopyGreen}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.1,
        height: 1.3,
      );

  // Ring percentage label inside CustomPaint progress rings
  static TextStyle ringPercent({Color color = AppColors.ink}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0,
        height: 1.2,
      );
}
