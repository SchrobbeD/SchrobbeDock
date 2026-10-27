import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schrobbedock_theme/schrobbedock_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeCustomizerDialog Responsive Tests', () {
    testWidgets('Opens as ModalBottomSheet on mobile viewport (< 600px) without overflow', (tester) async {
      tester.view.physicalSize = const Size(380, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SchrobbeDockThemeController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    SchrobbeDockTheme.showCustomizer(context, controller: controller);
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should find BottomSheet
      expect(find.byType(BottomSheet), findsOneWidget);
      // Header text
      expect(find.text('Uiterlijk & Thema'), findsOneWidget);
      // Donker mode label on mobile is compact 'Donker'
      expect(find.text('Donker'), findsOneWidget);
      // Tap on Tab 2: Colorpicker
      expect(find.text('Colorpicker'), findsOneWidget);
      await tester.tap(find.text('Colorpicker'));
      await tester.pumpAndSettle();

      // No overflows occurred
      expect(tester.takeException(), isNull);

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      controller.dispose();
    });

    testWidgets('Opens as Dialog on desktop/tablet viewport (>= 600px)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SchrobbeDockThemeController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    SchrobbeDockTheme.showCustomizer(context, controller: controller);
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should find Dialog instead of BottomSheet
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Uiterlijk & Thema Personalisatie'), findsOneWidget);
      expect(find.text('Donker (Slate)'), findsOneWidget);

      expect(tester.takeException(), isNull);

      // Close dialog via Klaar button
      await tester.tap(find.text('Klaar'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      controller.dispose();
    });
  });
}
