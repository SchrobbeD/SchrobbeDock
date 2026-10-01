import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hub_app/screens/admin_feedback_screen.dart';

void main() {
  testWidgets('AdminFeedbackScreen renders title and handles state gracefully', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminFeedbackScreen(),
        ),
      ),
    );

    // Initial loading or error state
    expect(find.text('Centraal Feedback- & Probleembeheer'), findsOneWidget);
  });
}
