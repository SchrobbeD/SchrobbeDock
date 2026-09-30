import 'package:flutter/material.dart';

class ThemePresetItem {
  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;

  const ThemePresetItem({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

class ThemePresets {
  static const ThemePresetItem amberRust = ThemePresetItem(
    id: 'amber_rust',
    name: 'Warm Amber & Roest',
    description: 'De officiële warme huisstijl van SchrobbeDock.',
    primaryColor: Color(0xFFEA580C), // Deep Warm Amber
    secondaryColor: Color(0xFFB45309), // Warm Rust
  );

  static const ThemePresetItem oceanDeep = ThemePresetItem(
    id: 'ocean_deep',
    name: 'Ocean Deep',
    description: 'Kalmerend marineblauw en oceaanaccenten.',
    primaryColor: Color(0xFF2563EB),
    secondaryColor: Color(0xFF1D4ED8),
  );

  static const ThemePresetItem emeraldForest = ThemePresetItem(
    id: 'emerald_forest',
    name: 'Emerald Forest',
    description: 'Natuurlijk smaragdgroen en fris mintaccent.',
    primaryColor: Color(0xFF059669),
    secondaryColor: Color(0xFF047857),
  );

  static const ThemePresetItem midnightViolet = ThemePresetItem(
    id: 'midnight_violet',
    name: 'Midnight Violet',
    description: 'Elegante paarse en lila tinten.',
    primaryColor: Color(0xFF7C3AED),
    secondaryColor: Color(0xFF6D28D9),
  );

  static const ThemePresetItem slateMonolith = ThemePresetItem(
    id: 'slate_monolith',
    name: 'Slate Monolith',
    description: 'Minimalistisch leisteen en neutraal titanium.',
    primaryColor: Color(0xFF475569),
    secondaryColor: Color(0xFF334155),
  );

  static const ThemePresetItem robHub = ThemePresetItem(
    id: 'rob_hub',
    name: 'RobHub',
    description: 'Exclusief parodiethema met puur zwart en fel geeloranje.',
    primaryColor: Color(0xFFFFA31A), // Iconic RobHub Orange
    secondaryColor: Color(0xFFE58E00), // Rich amber shadow
  );

  /// Officiële publieke presets voor iedereen
  static const List<ThemePresetItem> standardPresets = [
    amberRust,
    oceanDeep,
    emeraldForest,
    midnightViolet,
    slateMonolith,
  ];

  /// Alle presets inclusief exclusieve varianten (voor ID-lookup)
  static const List<ThemePresetItem> allPresets = [
    amberRust,
    oceanDeep,
    emeraldForest,
    midnightViolet,
    slateMonolith,
    robHub,
  ];

  static ThemePresetItem? findById(String id) {
    for (final p in allPresets) {
      if (p.id == id) return p;
    }
    return null;
  }
}
