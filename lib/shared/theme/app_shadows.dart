import 'package:flutter/material.dart';

// Statecraft — LOCKED: exactly two shadows.
// e1 "resting" (cards): 0,1 blur 2 @ 6% ink. e2 "raised" (sheets, dialogs,
// floating nav): 0,8 blur 24 @ 10% ink. Everything else = no shadow.
class AppShadows {
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color(0x0F141C17), // 6% ink
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color(0x1A141C17), // 10% ink
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const resting = e1;
  static const raised  = e2;
}
