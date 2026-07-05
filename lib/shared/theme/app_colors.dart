import 'package:flutter/material.dart';

class AppColors {
  // ── Primary palette (PRD token names) ─────────────────────────────────────
  static const canopyGreen = Color(0xFF006B3F); // primary actions, brand
  static const canopyMid   = Color(0xFF00552F); // gradient endpoint between deepCanopy and canopyGreen
  static const deepCanopy  = Color(0xFF00341E); // app bars, dark surfaces
  static const umbrellaRed = Color(0xFFCE1126); // destructive, alerts (sparing)
  static const paper       = Color(0xFFFBFBF8); // warm app background
  static const ink         = Color(0xFF12211A); // primary text (green-tinted near-black)
  static const mist        = Color(0xFF647169); // secondary text, labels

  // ── Surface & structural neutrals ─────────────────────────────────────────
  static const surface      = Color(0xFFFFFFFF); // card backgrounds
  static const hairline     = Color(0xFFE7EAE8); // dividers, rest borders
  static const fillMuted    = Color(0xFFF1F3F1); // chip/idle fills

  // ── Status tints ──────────────────────────────────────────────────────────
  static const greenTint = Color(0xFFE8F2EC);
  static const redTint   = Color(0xFFFBE9EB);
  static const amberTint = Color(0xFFFCF3E2);

  // ── Gold accent (pending / in-progress) ──────────────────────────────────
  static const gold     = Color(0xFFE8A317); // pending stat accent
  static const goldTint = Color(0xFFFCF3E2); // pending bg tint

  // ── Status semantic colors ─────────────────────────────────────────────────
  static const statusPending   = gold;        // amber/gold — matches PRD token
  static const statusActive    = canopyGreen;
  static const statusRejected  = umbrellaRed;
  static const statusSuspended = mist;

  static const pendingBg   = amberTint;
  static const activeBg    = greenTint;
  static const rejectedBg  = redTint;
  static const suspendedBg = fillMuted;

  // ── NDC flag stripe colors ─────────────────────────────────────────────────
  static const stripeBlack = Color(0xFF1A1A1A);
  static const stripeRed   = umbrellaRed;
  static const stripeWhite = surface;
  static const stripeGreen = canopyGreen;

  // ── Legacy aliases (kept for files not yet migrated) ──────────────────────
  static const ndcGreen     = canopyGreen;
  static const ndcRed       = umbrellaRed;
  static const ndcBlack     = Color(0xFF1A1A1A);
  static const ndcWhite     = Color(0xFFFFFFFF);
  static const ndcGold      = Color(0xFFFFCC00);

  static const background      = paper;
  static const surfaceVariant  = fillMuted;
  static const border          = hairline;
  static const divider         = hairline;

  static const textPrimary   = ink;
  static const textSecondary = mist;
  static const textMuted     = mist;
  static const textOnGreen   = Color(0xFFFFFFFF);

  static const greenLight = greenTint;
  static const greenMid   = Color(0xFF338C65);
  static const redLight   = redTint;
}
