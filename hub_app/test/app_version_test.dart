import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_app/config/app_version.dart';
import 'package:hub_app/widgets/app_version_badge.dart';
import 'package:hub_app/widgets/system_info_dialog.dart';

void main() {
  group('AppVersion unit tests', () {
    test('badgeDisplay and fullDisplay format correctly', () {
      expect(AppVersion.appVersion, isNotEmpty);
      expect(AppVersion.shortSha, isNotEmpty);
      expect(AppVersion.badgeDisplay, contains('v'));
      expect(AppVersion.fullDisplay, contains(AppVersion.shortSha));
    });

    test('formattedBuildTime returns expected fallback or formatted date', () {
      expect(AppVersion.formattedBuildTime, isNotEmpty);
    });
  });

  group('AppVersionBadge and SystemInfoDialog widget tests', () {
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

    testWidgets('Tapping AppVersionBadge opens SystemInfoDialog and can be closed', (tester) async {
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

      // Tap badge to open dialog
      await tester.tap(find.byType(AppVersionBadge));
      await tester.pumpAndSettle();

      expect(find.byType(SystemInfoDialog), findsOneWidget);
      expect(find.text('Systeem- & Versie-info'), findsOneWidget);
      expect(find.text('Git Commit'), findsOneWidget);
      expect(find.text('Backend Omgeving'), findsOneWidget);
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
            body: SystemInfoDialog(),
          ),
        ),
      );

      expect(find.text('Kopieer Diagnose Info'), findsOneWidget);
      await tester.tap(find.text('Kopieer Diagnose Info'));
      await tester.pump();

      expect(find.text('Diagnose-info gekopieerd naar klembord!'), findsOneWidget);
    });

    testWidgets('SystemInfoDialog hard reload button handles click in non-web test environment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SystemInfoDialog(),
          ),
        ),
      );

      final reloadButtonFinder = find.text('Cache Legen & Geforceerd Herladen');
      expect(reloadButtonFinder, findsOneWidget);
      await tester.tap(reloadButtonFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Cache gewist (in niet-web modus wordt niet herladen).'),
        findsOneWidget,
      );
    });
  });
}
