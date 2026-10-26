import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schrobbedock_auth/schrobbedock_auth.dart';

void main() {
  group('LoginRequiredView Tests', () {
    testWidgets('renders login required message and hub action button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginRequiredView(
            appName: 'Raket',
            hubUrl: 'https://robbedillen.be',
          ),
        ),
      );

      expect(find.text('Aanmelden Vereist'), findsOneWidget);
      expect(find.textContaining('Raket'), findsOneWidget);
      expect(find.text('Aanmelden via SchrobbeDock Hub'), findsOneWidget);
      expect(find.byIcon(Icons.lock_person_outlined), findsOneWidget);
    });
  });

  group('NoAccessView Tests', () {
    testWidgets('renders no access warning, code claim box and request access button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoAccessView(
            appSlug: 'raket',
            appName: 'Raket',
            hubUrl: 'https://robbedillen.be',
            initialHasPendingRequest: false,
          ),
        ),
      );

      expect(find.text('Geen Actieve Licentie'), findsOneWidget);
      expect(find.textContaining('Raket'), findsOneWidget);
      expect(find.text('Heb je een uitnodigingscode ontvangen?'), findsOneWidget);
      expect(find.text('Inwisselen'), findsOneWidget);
      expect(find.text('Toegang Aanvragen bij Beheerder'), findsOneWidget);
      expect(find.text('Terug naar SchrobbeDock Hub'), findsOneWidget);
    });

    testWidgets('renders pending banner when initialHasPendingRequest is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoAccessView(
            appSlug: 'raket',
            appName: 'Raket',
            hubUrl: 'https://robbedillen.be',
            initialHasPendingRequest: true,
          ),
        ),
      );

      expect(find.text('Je toegangsaanvraag is momenteel in behandeling bij de beheerder.'), findsOneWidget);
      // "Toegang Aanvragen" knop mag niet dubbel getoond worden
      expect(find.text('Toegang Aanvragen bij Beheerder'), findsNothing);
    });
  });
}
