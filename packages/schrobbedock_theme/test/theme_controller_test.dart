import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schrobbedock_theme/schrobbedock_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SchrobbeDockThemeController & Scope', () {
    test('Controller initializes with default preferences and notifies on preset change', () async {
      final controller = SchrobbeDockThemeController();
      expect(controller.preferences.preset, equals('amber_rust'));

      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.applyPreset(ThemePresets.oceanDeep);
      expect(notified, isTrue);
      expect(controller.preferences.preset, equals('ocean_deep'));
      expect(controller.preferences.primaryColor, equals(ThemePresets.oceanDeep.primaryColor));
      controller.dispose();
    });

    test('Controller handles custom colors and saved themes correctly', () async {
      final controller = SchrobbeDockThemeController();

      await controller.setCustomColors(
        primary: const Color(0xFF123456),
        secondary: const Color(0xFF654321),
      );

      expect(controller.preferences.preset, equals('custom'));
      expect(controller.preferences.primaryColor, equals(const Color(0xFF123456)));

      await controller.saveCurrentAsCustomTheme('Mijn Custom');
      expect(controller.preferences.savedThemes.length, equals(1));
      expect(controller.preferences.savedThemes.first.name, equals('Mijn Custom'));

      final savedId = controller.preferences.savedThemes.first.id;
      await controller.deleteSavedTheme(savedId);
      expect(controller.preferences.savedThemes.isEmpty, isTrue);
      controller.dispose();
    });

    testWidgets('SchrobbeDockThemeScope provides controller down the widget tree', (tester) async {
      final controller = SchrobbeDockThemeController();

      late ThemePreferences observedPrefs;
      await tester.pumpWidget(
        SchrobbeDockThemeScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              observedPrefs = SchrobbeDockThemeScope.preferencesOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(observedPrefs.preset, equals('amber_rust'));
      controller.dispose();
    });
  });
}
