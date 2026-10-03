import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';

void main() {
  group('SchrobbeDock Feedback Environment & Services', () {
    test('EnvironmentService collects valid platform metadata', () {
      final info = EnvironmentService.collect(null, appVersion: '1.2.3');
      expect(info['app_version'], equals('1.2.3'));
      expect(info['platform'], isNotNull);
      expect(info['timestamp'], isNotNull);
    });

    testWidgets('ScreenshotService handles missing RenderRepaintBoundary gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(width: 100, height: 100),
        ),
      );

      final BuildContext context = tester.element(find.byType(SizedBox));
      final bytes = await ScreenshotService.captureContext(context);
      // Returns null gracefully without crashing
      expect(bytes, isNull);
    });

    testWidgets('FeedbackDialog renders header and category options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedbackDialog(
              appSlug: 'dock_planner',
              initialTitle: 'Test Bug',
              initialDescription: 'Iets werkt niet',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Probleem Melden of Feedback'), findsOneWidget);
      expect(find.text('App: dock_planner'), findsOneWidget);
      expect(find.text('Bug / Fout'), findsOneWidget);
      expect(find.text('Verbetering'), findsOneWidget);
      expect(find.text('Vraag'), findsOneWidget);
      expect(find.text('Test Bug'), findsOneWidget);
      expect(find.text('Iets werkt niet'), findsOneWidget);
    });

    testWidgets('FeedbackDialog renders empty attachments state when no screenshot provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedbackDialog(
              appSlug: 'dock_planner',
              initialScreenshot: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BIJLAGEN (0/5)'), findsOneWidget);
      expect(find.text('Geen bijlagen (optioneel)'), findsOneWidget);
      expect(find.text('Toevoegen'), findsOneWidget);
    });

    testWidgets('FeedbackDialog renders attachment thumbnail and allows deletion', (tester) async {
      // 1x1 transparent PNG bytes
      final dummyBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackDialog(
              appSlug: 'dock_planner',
              initialScreenshot: dummyBytes,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BIJLAGEN (1/5)'), findsOneWidget);
      expect(find.text('Schermopname'), findsOneWidget);

      // Scroll naar het kruisje en klik om de schermafbeelding te verwijderen
      await tester.ensureVisible(find.byKey(const Key('delete_attachment_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_attachment_0')));
      await tester.pumpAndSettle();

      // Nu is er 0/5 bijlagen en zien we het lege bijlagen kaartje
      expect(find.text('BIJLAGEN (0/5)'), findsOneWidget);
      expect(find.text('Geen bijlagen (optioneel)'), findsOneWidget);
    });

    testWidgets('SchrobbeDockFeedbackOverlay displays floating action button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SchrobbeDockFeedbackOverlay(
              appSlug: 'dock_planner',
              child: Text('Main Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main Content'), findsOneWidget);
      expect(find.text('Hulp & Feedback'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
