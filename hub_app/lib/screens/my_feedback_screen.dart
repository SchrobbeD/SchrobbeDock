import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:schrobbedock_feedback/schrobbedock_feedback.dart';

class MyFeedbackScreen extends StatelessWidget {
  const MyFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeedbackPortalView(
      appSlug: null, // Toont alle meldingen over alle apps voor deze gebruiker
      isAdmin: false,
      onClose: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      },
    );
  }
}
