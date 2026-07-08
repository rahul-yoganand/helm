import 'package:flutter/material.dart';

/// Central app theme (Material 3, seeded scheme) — one place so every feature
/// renders consistently. Helm's seed is a deep nautical blue.
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF14476B);

  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      );

  /// Consistent per-status colors across board columns, chips, and activity.
  static Color statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'backlog':
        return scheme.outline;
      case 'in-progress':
        return scheme.primary;
      case 'in-review':
        return scheme.tertiary;
      case 'changes-requested':
        return scheme.error;
      case 'done':
        return Colors.green.harmonizeWith(scheme.primary);
      default:
        return scheme.outline;
    }
  }
}

extension on Color {
  /// Minimal stand-in for material_color_utilities' harmonize — keeps the
  /// green readable in both brightnesses without another dependency.
  Color harmonizeWith(Color _) => this;
}
