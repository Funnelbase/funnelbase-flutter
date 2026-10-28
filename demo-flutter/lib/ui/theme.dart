import 'package:flutter/material.dart';

/// The demo's palette, demo-android's `TradeDemoColors` value for value.
///
/// The violet accents are the dashboard's own brand ramp, so the demo and the analytics UI read as
/// one product. Green and red are reserved for price direction and are never the only signal —
/// every place they appear a ▲/▼ glyph appears with them.
abstract final class TradeColors {
  static const accent = Color(0xFF8B5CF6);
  static const accentMuted = Color(0xFF6D3FD6);
  static const onAccent = Color(0xFFFFFFFF);

  static const background = Color(0xFF0B0B10);
  static const surface = Color(0xFF15151E);
  static const surfaceElevated = Color(0xFF1D1D28);
  static const outline = Color(0xFF2E2E3D);

  static const textPrimary = Color(0xFFF2F2F7);
  static const textSecondary = Color(0xFF9E9EB3);

  static const up = Color(0xFF3DDC97);
  static const down = Color(0xFFFF6B6B);

  static const pending = Color(0xFFF5C451);
  static const filled = up;
  static const cancelled = Color(0xFF7C7C93);
}

/// Dark only, as on the other two demos: a trading app is a dark-UI genre, and a half-considered
/// light theme would look worse than none.
ThemeData tradeTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: TradeColors.accent,
      onPrimary: TradeColors.onAccent,
      primaryContainer: TradeColors.accentMuted,
      onPrimaryContainer: TradeColors.onAccent,
      surface: TradeColors.surface,
      onSurface: TradeColors.textPrimary,
      surfaceContainerHighest: TradeColors.surfaceElevated,
      onSurfaceVariant: TradeColors.textSecondary,
      outline: TradeColors.outline,
      outlineVariant: TradeColors.outline,
      error: TradeColors.down,
    ),
    scaffoldBackgroundColor: TradeColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: TradeColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: TradeColors.textPrimary,
    ),
    dividerTheme: const DividerThemeData(color: TradeColors.outline, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TradeColors.surface,
      indicatorColor: TradeColors.accentMuted,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? TradeColors.onAccent : TradeColors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? TradeColors.accent : TradeColors.textSecondary,
        ),
      ),
    ),
  );
}

/// Prices, quantities and totals in a monospaced face wherever they line up in a column, so the
/// decimal points form a straight edge down a list.
const numericStyle = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
  fontWeight: FontWeight.w500,
  fontSize: 15,
);
