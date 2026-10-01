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
