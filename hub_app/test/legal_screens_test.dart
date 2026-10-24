import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_app/screens/privacy_policy_screen.dart';
import 'package:hub_app/screens/terms_of_service_screen.dart';

void main() {
  group('Legal Screens Compliance Tests', () {
    testWidgets('PrivacyPolicyScreen renders headers, GDPR and Google API disclosures',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );

      // Verify header and title
      expect(find.text('Privacybeleid'), findsOneWidget);
      expect(find.text('SchrobbeDock Privacybeleid'), findsOneWidget);

      // Verify Google API limited use disclosure
      expect(find.text('4. Google API Limited Use Disclosure'), findsOneWidget);

      // Verify GDPR / Account deletion rights
      expect(
        find.text('6. Uw rechten & Recht op Vergetelheid (Zelfstandig Verwijderen)'),
        findsOneWidget,
      );
      expect(find.text('Begrepen & Terugkeren'), findsOneWidget);
    });

    testWidgets('TermsOfServiceScreen renders headers and terms sections',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: TermsOfServiceScreen(),
        ),
      );

      // Verify header and title
      expect(find.text('Gebruiksvoorwaarden'), findsOneWidget);
      expect(find.text('SchrobbeDock Gebruiksvoorwaarden'), findsOneWidget);

      // Verify sections
      expect(find.text('1. Toepasselijkheid'), findsOneWidget);
      expect(find.text('2. Toegang, Accounts & Uitnodigingen'), findsOneWidget);
      expect(find.text('3. Aanvaardbaar Gebruik'), findsOneWidget);
      expect(find.text('7. De Informele Pintjesclausule'), findsOneWidget);
      expect(find.text('8. Toepasselijk Recht'), findsOneWidget);
      expect(find.text('Begrepen & Terugkeren'), findsOneWidget);
    });
  });
}
