import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// Type scale: Display 32/38/700/-0.5 · H1 24/30/700/-0.3 · H2 20/26/600/-0.2
//             Title 17/24/600/0 · Body 15/22/400/0 · Label 13/18/500/0.1
//             Caption 12/16/500/0.2
//
// Display/headings → Bricolage Grotesque (character, authority)
// Body/UI          → Inter (neutral, sunlight-legible)
// Identifiers      → Inter tabular / IBM Plex Mono (data alignment)

class AppTextStyles {
  // ── Display ───────────────────────────────────────────────────────────────
  static TextStyle display({Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
        height: 38 / 32,
      );

  static TextStyle displayLarge({Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.0,
        height: 1.1,
      );

  // ── Eyebrow (small all-caps label above display headings) ────────────────
  static TextStyle eyebrow({Color color = AppColors.mist}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 1.5,
        height: 1.4,
      );

  // ── Headings ──────────────────────────────────────────────────────────────
  static TextStyle h1({Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
        height: 30 / 24,
      );

  static TextStyle h2({Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
        height: 26 / 20,
      );

  static TextStyle h3({Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0,
        height: 24 / 17,
      );

  // ── UI / body ─────────────────────────────────────────────────────────────
  static TextStyle title({Color color = AppColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        height: 24 / 17,
      );

  static TextStyle body({Color color = AppColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        height: 22 / 15,
      );

  static TextStyle bodyLarge({Color color = AppColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.6,
      );

  static TextStyle bodyMedium({Color color = AppColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color,
        height: 22 / 15,
      );

  static TextStyle label({Color color = AppColors.mist}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
        height: 18 / 13,
      );

  static TextStyle caption({Color color = AppColors.mist}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.2,
        height: 16 / 12,
      );

  static TextStyle small({Color color = AppColors.mist}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  // ── Identifiers (tabular / mono) ──────────────────────────────────────────
  static TextStyle memberNumber({Color color = AppColors.canopyGreen}) =>
      GoogleFonts.ibmPlexMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle timestamp({Color color = AppColors.mist}) =>
      GoogleFonts.ibmPlexMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle statNumber({Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
        height: 1.1,
      );

  static TextStyle statNumberLg({Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
        height: 1.1,
      );

  // ── App bar & buttons ─────────────────────────────────────────────────────
  static TextStyle appBarTitle({Color color = AppColors.surface}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle buttonText({Color color = AppColors.surface}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.1,
      );

  static TextStyle badge({Color color = AppColors.surface}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.3,
      );
}
