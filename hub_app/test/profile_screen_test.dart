import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_app/models/user_license.dart';
import 'package:hub_app/providers.dart';
import 'package:hub_app/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final dummyUser = User(
    id: 'test-user-uuid',
    appMetadata: {'provider': 'google'},
    userMetadata: {'name': 'Test User'},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00.000Z',
    email: 'test@schrobbedock.be',
  );

  final dummyLicenses = [
    UserLicense(
      id: 'lic-1',
      userId: 'test-user-uuid',
      appId: 'app-1',
      tier: 'PRO',
      role: 'ADMIN',
      createdAt: DateTime(2026, 1, 1),
      app: const AppInfo(
        id: 'app-1',
        slug: 'schrobbedock-pos',
        name: 'SchrobbeDock Kassa',
        isActive: true,
      ),
    ),
  ];

  testWidgets('ProfileScreen renders personal details, identity, and danger zone', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(dummyUser),
          userLicensesProvider.overrideWith((ref) => Future.value(dummyLicenses)),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial render
    expect(find.text('Mijn Profiel & Account'), findsOneWidget);
    expect(find.text('test@schrobbedock.be'), findsOneWidget);
    expect(find.text('Google OAuth'), findsOneWidget);
    expect(find.text('Persoonsgegevens'), findsOneWidget);
    expect(find.text('Mijn Actieve Licenties & Spoke Toegang'), findsOneWidget);
    expect(find.text('SchrobbeDock Kassa'), findsOneWidget);
    expect(find.text('Gevarenzone: Account Definitief Verwijderen'), findsOneWidget);
    expect(find.text('Mijn Account Definitief Verwijderen'), findsOneWidget);
  });

  testWidgets('Clicking delete account button opens confirmation modal with strict VERWIJDER check', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(dummyUser),
          userLicensesProvider.overrideWith((ref) => Future.value(dummyLicenses)),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ensure delete button in danger zone is visible and tap it
    final deleteButtonFinder = find.text('Mijn Account Definitief Verwijderen');
    expect(deleteButtonFinder, findsOneWidget);
    await tester.ensureVisible(deleteButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(deleteButtonFinder);
    await tester.pumpAndSettle();

    // Verify confirmation modal content
    expect(find.text('Account Definitief Verwijderen'), findsOneWidget);
    expect(
      find.textContaining('SchrobbeDock-account over het GEHELE ecosysteem'),
      findsOneWidget,
    );
    expect(
      find.textContaining('SchrobbeDock Hub (Centraal Profiel & Dashboard)'),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('SchrobbeDock Kassa')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Google Gekoppelde Apps'),
      findsOneWidget,
    );

    // Confirm button should initially be disabled
    final confirmButtonFinder = find.widgetWithText(FilledButton, 'Ja, Definitief Verwijderen');
    expect(confirmButtonFinder, findsOneWidget);
    final confirmButton = tester.widget<FilledButton>(confirmButtonFinder);
    expect(confirmButton.onPressed, isNull);

    // Type something other than VERWIJDER
    final inputFinder = find.byKey(const Key('delete_confirmation_input'));
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'verkeerd');
    await tester.pumpAndSettle();
    final confirmButtonStillDisabled = tester.widget<FilledButton>(confirmButtonFinder);
    expect(confirmButtonStillDisabled.onPressed, isNull);

    // Type exact keyword 'VERWIJDER'
    await tester.enterText(inputFinder, 'VERWIJDER');
    await tester.pumpAndSettle();
    final confirmButtonEnabled = tester.widget<FilledButton>(confirmButtonFinder);
    expect(confirmButtonEnabled.onPressed, isNotNull);

    // Dismiss dialog via 'Annuleren'
    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();

    expect(find.text('Ja, Definitief Verwijderen'), findsNothing);
  });
}
