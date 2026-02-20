/// Material 3 light + dark themes.
library;

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF00897B); // Teal 600

  static const List<Color> chartPalette = [
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFFEF5350),
    Color(0xFF26C6DA),
    Color(0xFF8D6E63),
    Color(0xFFD4E157),
    Color(0xFFEC407A),
    Color(0xFF78909C),
    Color(0xFF5C6BC0),
    Color(0xFF29B6F6),
    Color(0xFF9CCC65),
    Color(0xFFFFCA28),
    Color(0xFF26A69A),
    Color(0xFFFF7043),
    Color(0xFF7E57C2),
    Color(0xFF00ACC1),
    Color(0xFFAA00FF),
    Color(0xFFC0CA33),
    Color(0xFFFF8A65),
    Color(0xFF4DB6AC),
    Color(0xFF7986CB),
    Color(0xFFBA68C8),
  ];

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: _seed,
    fontFamily: 'Segoe UI',
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: _seed,
    fontFamily: 'Segoe UI',
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.black87, fontSize: 12),
    ),
  );

  static Color shimmerBase(Brightness b) =>
      b == Brightness.light ? const Color(0xFFE0E0E0) : const Color(0xFF424242);
  static Color shimmerHighlight(Brightness b) =>
      b == Brightness.light ? const Color(0xFFF5F5F5) : const Color(0xFF616161);
}
