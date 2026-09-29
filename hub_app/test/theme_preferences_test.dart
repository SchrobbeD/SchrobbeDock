import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_app/theme/schrobbedock_theme.dart';

void main() {
  group('ThemePreferences & Color Conversions', () {
    test('Default preferences are Warm Amber & Roest with system mode', () {
      const prefs = ThemePreferences.defaultPreferences;
      expect(prefs.themeMode, equals(ThemeMode.system));
      expect(prefs.preset, equals('amber_rust'));
      expect(colorToHex(prefs.primaryColor), equals('#EA580C'));
      expect(colorToHex(prefs.secondaryColor), equals('#B45309'));
    });

    test('toJson and fromJson preserves data accurately', () {
      const original = ThemePreferences(
        themeMode: ThemeMode.dark,
        primaryColor: Color(0xFF2563EB),
        secondaryColor: Color(0xFF1D4ED8),
        preset: 'ocean_deep',
      );

      final json = original.toJson();
      expect(json['theme_mode'], equals('dark'));
      expect(json['primary_color'], equals('#2563EB'));
      expect(json['secondary_color'], equals('#1D4ED8'));
      expect(json['preset'], equals('ocean_deep'));

      final parsed = ThemePreferences.fromJson(json);
      expect(parsed, equals(original));
    });

    test('fromUserMetadata correctly parses nested metadata structure', () {
      final metadata = {
        'preferences': {
          'theme_mode': 'light',
          'primary_color': '#059669',
          'secondary_color': '#047857',
          'preset': 'emerald_forest',
        }
      };

      final parsed = ThemePreferences.fromUserMetadata(metadata);
      expect(parsed.themeMode, equals(ThemeMode.light));
      expect(parsed.preset, equals('emerald_forest'));
      expect(colorToHex(parsed.primaryColor), equals('#059669'));
    });

    test('Color hex parsing handles 6-digit and 8-digit formats', () {
      expect(colorFromHex('#EA580C').toARGB32(), equals(const Color(0xFFEA580C).toARGB32()));
      expect(colorFromHex('EA580C').toARGB32(), equals(const Color(0xFFEA580C).toARGB32()));
      expect(colorFromHex('#FFEA580C').toARGB32(), equals(const Color(0xFFEA580C).toARGB32()));
    });

    test('AppTheme generates valid light and dark ThemeData with slate tokens', () {
      const prefs = ThemePreferences.defaultPreferences;
      final lightTheme = AppTheme.buildLightTheme(prefs);
      final darkTheme = AppTheme.buildDarkTheme(prefs);

      expect(lightTheme.brightness, equals(Brightness.light));
      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(darkTheme.scaffoldBackgroundColor, equals(AppTheme.slate900));
      expect(darkTheme.cardTheme.color, equals(AppTheme.slate800));
      expect(darkTheme.colorScheme.primary, equals(prefs.primaryColor));
    });

    test('SavedTheme serialization and list parsing works seamlessly', () {
      final saved = const SavedTheme(
        id: 'test_123',
        name: 'Mijn Bedrijfsstijl',
        primaryColor: Color(0xFF10B981),
        secondaryColor: Color(0xFF047857),
        themeMode: ThemeMode.dark,
      );

      final prefs = ThemePreferences(
        savedThemes: [saved],
      );

      final json = prefs.toJson();
      final parsed = ThemePreferences.fromJson(json);

      expect(parsed.savedThemes.length, equals(1));
      expect(parsed.savedThemes.first.name, equals('Mijn Bedrijfsstijl'));
      expect(colorToHex(parsed.savedThemes.first.primaryColor), equals('#10B981'));
      expect(parsed.savedThemes.first.themeMode, equals(ThemeMode.dark));
    });
  });
}
