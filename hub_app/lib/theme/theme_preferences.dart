import 'package:flutter/material.dart';

Color colorFromHex(String hexString, [Color fallback = const Color(0xFFEA580C)]) {
  try {
    String formatted = hexString.replaceAll('#', '').trim();
    if (formatted.length == 6) {
      formatted = 'FF$formatted';
    }
    if (formatted.length == 8) {
      return Color(int.parse('0x$formatted'));
    }
  } catch (_) {}
  return fallback;
}

String colorToHex(Color color, {bool includeAlpha = false}) {
  final a = ((color.a * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
  final r = ((color.r * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
  final g = ((color.g * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
  final b = ((color.b * 255).round() & 0xFF).toRadixString(16).padLeft(2, '0');
  if (includeAlpha) {
    return '#$a$r$g$b'.toUpperCase();
  }
  return '#$r$g$b'.toUpperCase();
}

class ThemePreferences {
  final ThemeMode themeMode;
  final Color primaryColor;
  final Color secondaryColor;
  final String preset;

  const ThemePreferences({
    this.themeMode = ThemeMode.system,
    this.primaryColor = const Color(0xFFEA580C), // Deep Warm Amber
    this.secondaryColor = const Color(0xFFB45309), // Warm Rust
    this.preset = 'amber_rust',
  });

  static const ThemePreferences defaultPreferences = ThemePreferences();

  factory ThemePreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return defaultPreferences;
    }

    ThemeMode mode = ThemeMode.system;
    final modeStr = json['theme_mode']?.toString().toLowerCase();
    if (modeStr == 'light') {
      mode = ThemeMode.light;
    } else if (modeStr == 'dark') {
      mode = ThemeMode.dark;
    }

    final primaryHex = json['primary_color']?.toString() ?? '#EA580C';
    final secondaryHex = json['secondary_color']?.toString() ?? '#B45309';
    final presetName = json['preset']?.toString() ?? 'amber_rust';

    return ThemePreferences(
      themeMode: mode,
      primaryColor: colorFromHex(primaryHex, const Color(0xFFEA580C)),
      secondaryColor: colorFromHex(secondaryHex, const Color(0xFFB45309)),
      preset: presetName,
    );
  }

  factory ThemePreferences.fromUserMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return defaultPreferences;
    final prefsData = metadata['preferences'];
    if (prefsData is Map<String, dynamic>) {
      return ThemePreferences.fromJson(prefsData);
    }
    return defaultPreferences;
  }

  Map<String, dynamic> toJson() {
    String modeStr = 'system';
    if (themeMode == ThemeMode.light) modeStr = 'light';
    if (themeMode == ThemeMode.dark) modeStr = 'dark';

    return {
      'theme_mode': modeStr,
      'primary_color': colorToHex(primaryColor),
      'secondary_color': colorToHex(secondaryColor),
      'preset': preset,
    };
  }

  ThemePreferences copyWith({
    ThemeMode? themeMode,
    Color? primaryColor,
    Color? secondaryColor,
    String? preset,
  }) {
    return ThemePreferences(
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      preset: preset ?? this.preset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemePreferences &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          primaryColor == other.primaryColor &&
          secondaryColor == other.secondaryColor &&
          preset == other.preset;

  @override
  int get hashCode =>
      themeMode.hashCode ^
      primaryColor.hashCode ^
      secondaryColor.hashCode ^
      preset.hashCode;
}
