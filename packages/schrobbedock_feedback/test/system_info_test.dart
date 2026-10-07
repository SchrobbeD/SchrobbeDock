import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';

void main() {
  group('AppVersion in schrobbedock_feedback tests', () {
    test('badgeDisplay and fullDisplay format correctly', () {
      expect(AppVersion.appVersion, isNotEmpty);
      expect(AppVersion.shortSha, isNotEmpty);
      expect(AppVersion.badgeDisplay, contains('v'));
      expect(AppVersion.fullDisplay, contains(AppVersion.shortSha));
    });

    test('formattedBuildTime returns fallback in local dev', () {
      expect(AppVersion.formattedBuildTime, isNotEmpty);
    });
  });

  group('AppVersionBadge and SystemInfoDialog widget tests in package', () {
    testWidgets('AppVersionBadge renders and shows badgeDisplay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [
                AppVersionBadge(),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AppVersionBadge), findsOneWidget);
      expect(find.text(AppVersion.badgeDisplay), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('Tapping AppVersionBadge opens SystemInfoDialog and shows clickable backend url', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [
                AppVersionBadge(customBackendUrl: 'https://test.supabase.co'),
              ],
            ),
          ),
        ),
      );

      // Tap badge to open dialog
      await tester.tap(find.byType(AppVersionBadge));
      await tester.pumpAndSettle();

      expect(find.byType(SystemInfoDialog), findsOneWidget);
      expect(find.text('Systeem- & Versie-info'), findsOneWidget);
      expect(find.text('Git Commit'), findsOneWidget);
      expect(find.textContaining('https://test.supabase.co'), findsOneWidget);
      expect(find.text('Cache Legen & Geforceerd Herladen'), findsOneWidget);

      // Tap 'Sluiten' button to dismiss dialog
      await tester.tap(find.text('Sluiten'));
      await tester.pumpAndSettle();

      expect(find.byType(SystemInfoDialog), findsNothing);
    });

    testWidgets('SystemInfoDialog diagnose copy button works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SystemInfoDialog(customBackendUrl: 'https://test.supabase.co'),
          ),
        ),
      );

      expect(find.text('Kopieer Diagnose Info'), findsOneWidget);
      await tester.tap(find.text('Kopieer Diagnose Info'));
      await tester.pump();

      expect(find.text('Diagnose-info gekopieerd naar klembord!'), findsOneWidget);
    });

    testWidgets('SystemInfoDialog hard reload button handles click in test environment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SystemInfoDialog(customBackendUrl: 'https://test.supabase.co'),
          ),
        ),
      );

      final reloadButtonFinder = find.text('Cache Legen & Geforceerd Herladen');
      expect(reloadButtonFinder, findsOneWidget);
      await tester.ensureVisible(reloadButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(reloadButtonFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Cache gewist (in niet-web modus wordt niet herladen).'),
        findsOneWidget,
      );
    });
  });
}
