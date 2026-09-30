import 'package:flutter/material.dart';
import 'theme_preferences.dart';

class AppTheme {
  // Slate kleurentokens voor donkere modus
  static const Color slate950 = Color(0xFF020617);
  static const Color slate900 = Color(0xFF0F172A); // Scaffold achtergrond
  static const Color slate850 = Color(0xFF162032);
  static const Color slate800 = Color(0xFF1E293B); // Kaarten & panelen
  static const Color slate700 = Color(0xFF334155); // Randen & scheidingslijnen
  static const Color slate600 = Color(0xFF475569);
  static const Color slate400 = Color(0xFF94A3B8); // Secundaire tekst
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0); // Lichte modus randen
  static const Color slate100 = Color(0xFFF1F5F9); // Lichte modus hover
  static const Color slate50 = Color(0xFFF8FAFC);  // Lichte modus achtergrond

  static ThemeData buildLightTheme(ThemePreferences prefs) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: prefs.primaryColor,
      brightness: Brightness.light,
    );

    final colorScheme = baseColorScheme.copyWith(
      primary: prefs.primaryColor,
      secondary: prefs.secondaryColor,
      surface: Colors.white,
      surfaceContainerHighest: slate100,
      outline: slate200,
      outlineVariant: slate200,
      onSurface: slate900,
      onSurfaceVariant: const Color(0xFF475569),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: slate50,
      canvasColor: slate50,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: slate900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: slate900,
          letterSpacing: -0.3,
        ),
        shape: const Border(
          bottom: BorderSide(color: slate200, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: slate200, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: slate200, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: prefs.primaryColor.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: prefs.primaryColor,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: prefs.primaryColor);
          }
          return const IconThemeData(color: Color(0xFF64748B));
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: prefs.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate900,
          side: const BorderSide(color: slate200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: prefs.primaryColor, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: slate200,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData buildDarkTheme(ThemePreferences prefs) {
    final isRobHub = prefs.preset == 'rob_hub';

    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: prefs.primaryColor,
      brightness: Brightness.dark,
    );

    final surfaceColor = isRobHub ? const Color(0xFF141416) : slate800;
    final surfaceContainerHighest = isRobHub ? const Color(0xFF1F1F23) : slate850;
    final outlineColor = isRobHub ? const Color(0xFF2E2E32) : slate700;
    final scaffoldBg = isRobHub ? const Color(0xFF09090B) : slate900;
    final onPrimaryColor = isRobHub ? Colors.black : Colors.white;

    final colorScheme = baseColorScheme.copyWith(
      primary: prefs.primaryColor,
      secondary: prefs.secondaryColor,
      surface: surfaceColor,
      surfaceContainerHighest: surfaceContainerHighest,
      outline: outlineColor,
      outlineVariant: outlineColor,
      onPrimary: onPrimaryColor,
      onSurface: const Color(0xFFF8FAFC),
      onSurfaceVariant: isRobHub ? const Color(0xFFA1A1AA) : slate400,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FAFC),
          letterSpacing: -0.3,
        ),
        shape: Border(
          bottom: BorderSide(color: outlineColor, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: outlineColor, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outlineColor, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: prefs.primaryColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: prefs.primaryColor,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: slate400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: prefs.primaryColor);
          }
          return const IconThemeData(color: slate400);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: prefs.primaryColor,
          foregroundColor: onPrimaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: TextStyle(
            fontWeight: isRobHub ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF8FAFC),
          side: BorderSide(color: outlineColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: prefs.primaryColor, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
