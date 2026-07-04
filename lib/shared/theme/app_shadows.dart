import 'package:flutter/material.dart';

// Two shadows only. Everything else = no shadow.
// e1 — resting cards; e2 — menus, sheets, FAB.
class AppShadows {
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color(0x0A12211A), // rgba(18,33,26,0.04)
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0812211A), // rgba(18,33,26,0.03)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color(0x1A12211A), // rgba(18,33,26,0.10)
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
