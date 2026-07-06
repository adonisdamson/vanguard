import 'package:flutter/material.dart';

// One consistent radius set. Kill every other radius in the codebase.
class AppRadii {
  // Statecraft — LOCKED: inputs/buttons 14 · cards 18 · sheets/dialogs 24
  static const double xs   = 6;  // skeleton bars, micro chips
  static const double sm   = 14; // buttons, inputs, chips
  static const double md   = 18; // cards, sheet rows
  static const double lg   = 24; // bottom-sheet top, dialogs
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
