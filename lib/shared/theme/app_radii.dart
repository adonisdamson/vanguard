import 'package:flutter/material.dart';

// One consistent radius set. Kill every other radius in the codebase.
class AppRadii {
  // LOCKED: sm 8 (chips/badges/inputs) · md 12 (cards/rows) · lg 16 (hero/sheets)
  static const double xs   = 6;  // skeleton bars, micro chips
  static const double sm   = 8;  // buttons, inputs, chips, badges
  static const double md   = 12; // cards, sheet rows
  static const double lg   = 16; // hero banners, bottom-sheet top, dialogs
  static const double pill = 999; // filter chips, status pills

  static const BorderRadius borderXs   = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderSm   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderPill = BorderRadius.all(Radius.circular(pill));

  // Bottom-sheet: only top corners rounded
  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft:  Radius.circular(lg),
    topRight: Radius.circular(lg),
  );
}
