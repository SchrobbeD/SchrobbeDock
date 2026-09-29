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

class SavedTheme {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final ThemeMode themeMode;

  const SavedTheme({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    this.themeMode = ThemeMode.system,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primary_color': colorToHex(primaryColor),
        'secondary_color': colorToHex(secondaryColor),
        'theme_mode': themeMode == ThemeMode.dark
            ? 'dark'
            : (themeMode == ThemeMode.light ? 'light' : 'system'),
      };

  factory SavedTheme.fromJson(Map<String, dynamic> json) {
    ThemeMode mode = ThemeMode.system;
    final modeStr = json['theme_mode']?.toString().toLowerCase();
    if (modeStr == 'light') mode = ThemeMode.light;
    if (modeStr == 'dark') mode = ThemeMode.dark;

    return SavedTheme(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Mijn Thema',
      primaryColor:
          colorFromHex(json['primary_color']?.toString() ?? '#EA580C'),
      secondaryColor:
          colorFromHex(json['secondary_color']?.toString() ?? '#B45309'),
      themeMode: mode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedTheme &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          primaryColor == other.primaryColor &&
          secondaryColor == other.secondaryColor &&
          themeMode == other.themeMode;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      primaryColor.hashCode ^
      secondaryColor.hashCode ^
      themeMode.hashCode;
}

class ThemePreferences {
  final ThemeMode themeMode;
  final Color primaryColor;
  final Color secondaryColor;
  final String preset;
  final List<SavedTheme> savedThemes;

  const ThemePreferences({
    this.themeMode = ThemeMode.system,
    this.primaryColor = const Color(0xFFEA580C), // Deep Warm Amber
    this.secondaryColor = const Color(0xFFB45309), // Warm Rust
    this.preset = 'amber_rust',
    this.savedThemes = const [],
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

    List<SavedTheme> parsedSaved = [];
    if (json['saved_themes'] is List) {
      parsedSaved = (json['saved_themes'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => SavedTheme.fromJson(e))
          .toList();
    }

    return ThemePreferences(
      themeMode: mode,
      primaryColor: colorFromHex(primaryHex, const Color(0xFFEA580C)),
      secondaryColor: colorFromHex(secondaryHex, const Color(0xFFB45309)),
      preset: presetName,
      savedThemes: parsedSaved,
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
      'saved_themes': savedThemes.map((e) => e.toJson()).toList(),
    };
  }

  ThemePreferences copyWith({
    ThemeMode? themeMode,
    Color? primaryColor,
    Color? secondaryColor,
    String? preset,
    List<SavedTheme>? savedThemes,
  }) {
    return ThemePreferences(
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      preset: preset ?? this.preset,
      savedThemes: savedThemes ?? this.savedThemes,
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
          preset == other.preset &&
          _listEquals(savedThemes, other.savedThemes);

  @override
  int get hashCode =>
      themeMode.hashCode ^
      primaryColor.hashCode ^
      secondaryColor.hashCode ^
      preset.hashCode ^
      savedThemes.hashCode;

  static bool _listEquals(List<SavedTheme> a, List<SavedTheme> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
