import 'package:flutter/material.dart';

/// Statecraft palette — LOCKED (VANGUARD_REBUILD_V2.md §C0). One brand color
/// doing all the talking, one warm neutral scale, exactly three semantic
/// colors, gold reserved for the approved checkmark / executive badge.
/// Do not add colors here without amending the design doc first.
class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const brand      = Color(0xFF006B3F); // NDC green — primary buttons, active states
  static const brand900   = Color(0xFF0B3D1F); // hero/header bands (deep, rich)
  static const brandDeep  = Color(0xFF00522F); // pressed states, band depth
  static const brandTint  = Color(0xFFE4F0E8); // selected bg, avatar fallback, icon chips

  // ── Neutrals ───────────────────────────────────────────────────────────────
  static const canvas   = Color(0xFFF4F6F5); // screen background (green-tinted off-white)
  static const surface  = Color(0xFFFFFFFF); // cards, sheets, inputs
  static const ink      = Color(0xFF14181B); // headings, primary text
  static const inkMuted = Color(0xFF5B6670); // secondary text, captions, inactive icons
  static const line     = Color(0xFFD8DEE2); // hairline borders, dividers
  static const fillMuted = Color(0xFFF1F3F1); // idle chip/skeleton fills

  // ── Semantic (the only three) ──────────────────────────────────────────────
  static const success = Color(0xFF1B7F4D); // approved
  static const warning = Color(0xFFB7791F); // pending
  static const danger  = Color(0xFFB3261E); // rejected / destructive

  // ── Gold — ONE use: approved-member checkmark & executive badge ────────────
  static const gold = Color(0xFFC9A227);

  // ── Soft tints (status backgrounds, banners) ───────────────────────────────
  static const greenTint = brandTint;
  static const redTint   = Color(0xFFF9EAE9);
  static const amberTint = Color(0xFFF7EFDC);
  static const goldTint  = amberTint;

  // ── Established names (every existing screen uses these) ──────────────────
  static const canopyGreen = brand;
  static const canopyMid   = brandDeep;
  static const deepCanopy  = brand900;  // hero/header bands: deep rich green
  static const umbrellaRed = danger;
  static const paper       = canvas;
  static const mist        = inkMuted;
  static const hairline    = line;

  static const statusPending   = warning;
  static const statusActive    = success;
  static const statusRejected  = danger;
  static const statusSuspended = inkMuted;

  static const pendingBg   = amberTint;
  static const activeBg    = greenTint;
  static const rejectedBg  = redTint;
  static const suspendedBg = fillMuted;

  // ── NDC flag stripe colors (brand device only, not UI chrome) ─────────────
  static const stripeBlack = Color(0xFF1A1A1A);
  static const stripeRed   = Color(0xFFCE1126); // official flag red, stripe only
  static const stripeWhite = surface;
  static const stripeGreen = brand;

  // ── Legacy aliases (kept for files not yet migrated) ──────────────────────
  static const ndcGreen = brand;
  static const ndcRed   = danger;
  static const ndcBlack = Color(0xFF1A1A1A);
  static const ndcWhite = Color(0xFFFFFFFF);
  static const ndcGold  = gold;

  static const background     = canvas;
  static const surfaceVariant = fillMuted;
  static const border         = line;
  static const divider        = line;

  static const textPrimary   = ink;
  static const textSecondary = inkMuted;
  static const textMuted     = inkMuted;
  static const textOnGreen   = Color(0xFFFFFFFF);

  static const greenLight = brandTint;
  static const greenMid   = Color(0xFF338C65);
  static const redLight   = redTint;
}
